import Accelerate
import AVFAudio
import Combine
import Foundation
import ShazamKit

struct ShazamRecognizedTrack: Equatable, Sendable {
    let title: String
    let artistName: String
    let shazamID: String?
    let isrc: String?
    let recognizedAt: Date
    let recognitionTime: TimeInterval
}

struct ShazamRecognitionGap: Equatable, Sendable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
}

enum ShazamRecognitionState: Equatable {
    case idle
    case preparing
    case listening
    case paused
    case interrupted
    case recovering
    case microphonePermissionDenied
    case failed
}

@MainActor
final class ShazamRecognitionService: NSObject, ObservableObject {
    @Published private(set) var state: ShazamRecognitionState = .idle
    @Published private(set) var latestMatch: ShazamRecognizedTrack?
    @Published private(set) var elapsedDuration: TimeInterval = 0
    @Published private(set) var activeGapStartTime: TimeInterval?
    @Published private(set) var inputLevel: Double = 0

    private var audioEngine = AVAudioEngine()
    private var mixerNode = AVAudioMixerNode()
    private var shazamSession = SHSession()
    private var isAudioEngineConfigured = false
    private let gapThreshold: TimeInterval
    private var accumulatedListeningDuration: TimeInterval = 0
    private var listeningStartedAt: Date?
    private var unmatchedStartTime: TimeInterval?
    private var gapThresholdTask: Task<Void, Never>?
    private var elapsedUpdateTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var startRequestID: UUID?
    private var shouldResumeAfterInterruption = false

    init(gapThreshold: TimeInterval = 60) {
        self.gapThreshold = gapThreshold
        super.init()
        shazamSession.delegate = self
        observeAudioSessionLifecycle()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func restoreElapsedDuration(_ duration: TimeInterval) {
        guard state == .idle, listeningStartedAt == nil else { return }
        accumulatedListeningDuration = max(0, duration)
        elapsedDuration = accumulatedListeningDuration
    }

    func start() async {
        guard !state.hasActiveSession else { return }
        let requestID = UUID()
        startRequestID = requestID
        state = .preparing

        let permissionGranted = await AVAudioApplication.requestRecordPermission()
        guard startRequestID == requestID, state == .preparing else { return }
        guard permissionGranted else {
            startRequestID = nil
            state = .microphonePermissionDenied
            return
        }

        do {
            try configureAudioSession()
            try rebuildRecognitionPipeline()
            audioEngine.prepare()
            try audioEngine.start()
            listeningStartedAt = .now
            startRequestID = nil
            state = .listening
            startElapsedUpdates()
            scheduleGapThresholdIfNeeded()
        } catch {
            guard startRequestID == requestID else { return }
            failRecognition()
        }
    }

    func toggleListening() async {
        switch state {
        case .listening:
            pauseRecognition()
        case .paused, .idle, .microphonePermissionDenied, .failed:
            await start()
        case .preparing, .interrupted, .recovering:
            pauseRecognition()
        }
    }

    func setListening(_ shouldListen: Bool) async {
        if shouldListen {
            guard !state.hasActiveSession else { return }
            await start()
        } else {
            guard state.hasActiveSession else { return }
            await toggleListening()
        }
    }

    func confirmAcceptedMatch(
        at recognitionTime: TimeInterval
    ) -> ShazamRecognitionGap? {
        let gap = finishActiveGap(at: recognitionTime)
        resetUnmatchedPeriod()
        return gap
    }

    @discardableResult
    func stop() -> ShazamRecognitionGap? {
        updateElapsedDuration()
        listeningStartedAt = nil
        elapsedUpdateTask?.cancel()
        gapThresholdTask?.cancel()
        recoveryTask?.cancel()
        startRequestID = nil
        shouldResumeAfterInterruption = false

        var completedGap: ShazamRecognitionGap?
        if let unmatchedStartTime,
           elapsedDuration - unmatchedStartTime >= gapThreshold {
            activateGapIfNeeded()
            completedGap = finishActiveGap(at: elapsedDuration)
        }
        resetUnmatchedPeriod()

        tearDownRecognitionPipeline()
        deactivateAudioSession()
        state = .idle
        return completedGap
    }

    private func pauseRecognition() {
        if listeningStartedAt != nil {
            updateElapsedDuration()
        }
        listeningStartedAt = nil
        elapsedUpdateTask?.cancel()
        gapThresholdTask?.cancel()
        recoveryTask?.cancel()
        startRequestID = nil
        shouldResumeAfterInterruption = false
        state = .paused
        tearDownRecognitionPipeline()
        deactivateAudioSession()
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try audioSession.setActive(true)
    }

    private func observeAudioSessionLifecycle() {
        let center = NotificationCenter.default
        let audioSession = AVAudioSession.sharedInstance()

        center.addObserver(
            self,
            selector: #selector(receiveAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        center.addObserver(
            self,
            selector: #selector(receiveAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
        center.addObserver(
            self,
            selector: #selector(receiveMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession
        )
    }

    @objc nonisolated private func receiveAudioSessionInterruption(
        _ notification: Notification
    ) {
        let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0

        Task { @MainActor [weak self] in
            self?.handleAudioSessionInterruption(
                rawType: rawType,
                rawOptions: rawOptions
            )
        }
    }

    @objc nonisolated private func receiveAudioRouteChange(
        _ notification: Notification
    ) {
        let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt

        Task { @MainActor [weak self] in
            self?.handleAudioRouteChange(rawReason: rawReason)
        }
    }

    @objc nonisolated private func receiveMediaServicesReset(
        _ notification: Notification
    ) {
        Task { @MainActor [weak self] in
            self?.schedulePipelineRecovery()
        }
    }

    private func handleAudioSessionInterruption(
        rawType: UInt?,
        rawOptions: UInt
    ) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            guard state == .listening, listeningStartedAt != nil else { return }
            updateElapsedDuration()
            listeningStartedAt = nil
            elapsedUpdateTask?.cancel()
            gapThresholdTask?.cancel()
            shouldResumeAfterInterruption = true
            tearDownRecognitionPipeline()
            state = .interrupted

        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            guard shouldResumeAfterInterruption else { return }
            shouldResumeAfterInterruption = false

            if options.contains(.shouldResume) {
                schedulePipelineRecovery()
            } else {
                state = .paused
                deactivateAudioSession()
            }

        @unknown default:
            break
        }
    }

    private func handleAudioRouteChange(rawReason: UInt?) {
        guard
            state == .listening,
            listeningStartedAt != nil,
            let rawReason,
            let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason)
        else {
            return
        }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            schedulePipelineRecovery()
        default:
            break
        }
    }

    private func schedulePipelineRecovery() {
        guard state == .listening || state == .interrupted else { return }
        recoveryTask?.cancel()
        state = .recovering
        recoveryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                try self?.recoverRecognitionPipeline()
            } catch is CancellationError {
                return
            } catch {
                self?.failRecognition()
            }
        }
    }

    private func recoverRecognitionPipeline() throws {
        guard state == .recovering else { return }

        if listeningStartedAt != nil {
            updateElapsedDuration()
        }
        listeningStartedAt = nil
        elapsedUpdateTask?.cancel()
        gapThresholdTask?.cancel()

        try configureAudioSession()
        try rebuildRecognitionPipeline()
        audioEngine.prepare()
        try audioEngine.start()

        listeningStartedAt = .now
        state = .listening
        startElapsedUpdates()
        scheduleGapThresholdIfNeeded()
    }

    private func failRecognition() {
        if listeningStartedAt != nil {
            updateElapsedDuration()
        }
        listeningStartedAt = nil
        elapsedUpdateTask?.cancel()
        gapThresholdTask?.cancel()
        recoveryTask?.cancel()
        startRequestID = nil
        shouldResumeAfterInterruption = false
        tearDownRecognitionPipeline()
        deactivateAudioSession()
        state = .failed
    }

    private func rebuildRecognitionPipeline() throws {
        tearDownRecognitionPipeline()

        audioEngine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()
        shazamSession = SHSession()
        shazamSession.delegate = self

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw ShazamRecognitionError.unavailableAudioInput
        }
        guard let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: 1
        ) else {
            throw ShazamRecognitionError.unavailableAudioInput
        }

        audioEngine.attach(mixerNode)
        audioEngine.connect(inputNode, to: mixerNode, format: inputFormat)
        audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: outputFormat)
        audioEngine.mainMixerNode.outputVolume = 0

        let session = shazamSession
        mixerNode.installTap(
            onBus: 0,
            bufferSize: 8_192,
            format: outputFormat
        ) { [weak self] buffer, audioTime in
            session.matchStreamingBuffer(buffer, at: audioTime)

            let inputLevel = Self.normalizedInputLevel(from: buffer)
            Task { @MainActor [weak self] in
                self?.updateInputLevel(inputLevel)
            }
        }
        isAudioEngineConfigured = true
    }

    private func tearDownRecognitionPipeline() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if isAudioEngineConfigured {
            mixerNode.removeTap(onBus: 0)
        }
        audioEngine.reset()
        shazamSession.delegate = nil
        isAudioEngineConfigured = false
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func updateInputLevel(_ newLevel: Double) {
        guard state == .listening else { return }

        let smoothingFactor = newLevel > inputLevel ? 0.58 : 0.24
        inputLevel += (newLevel - inputLevel) * smoothingFactor
    }

    nonisolated private static func normalizedInputLevel(
        from buffer: AVAudioPCMBuffer
    ) -> Double {
        guard
            buffer.frameLength > 0,
            let channelData = buffer.floatChannelData?[0]
        else {
            return 0
        }

        var rootMeanSquare: Float = 0
        vDSP_rmsqv(
            channelData,
            1,
            &rootMeanSquare,
            vDSP_Length(buffer.frameLength)
        )

        let decibels = 20 * log10(max(rootMeanSquare, 0.000_001))
        let noiseFloor: Float = -60
        let loudLevel: Float = -6
        let normalized = min(
            max((decibels - noiseFloor) / (loudLevel - noiseFloor), 0),
            1
        )
        return Double(pow(normalized, 1.35))
    }

    private func accept(match: SHMatch) {
        guard
            let item = match.mediaItems.first,
            let title = item.title,
            let artistName = item.artist
        else {
            return
        }

        updateElapsedDuration()
        let recognitionTime = elapsedDuration

        let now = Date.now
        latestMatch = ShazamRecognizedTrack(
            title: title,
            artistName: artistName,
            shazamID: item.shazamID,
            isrc: item.isrc,
            recognizedAt: now,
            recognitionTime: recognitionTime
        )
    }

    private func handleNoMatch() {
        guard state == .listening else { return }
        updateElapsedDuration()

        if unmatchedStartTime == nil {
            unmatchedStartTime = elapsedDuration
        }
        scheduleGapThresholdIfNeeded()
    }

    private func scheduleGapThresholdIfNeeded() {
        gapThresholdTask?.cancel()
        guard state == .listening, let unmatchedStartTime else { return }

        let elapsedUnmatchedTime = currentElapsedDuration - unmatchedStartTime
        let remainingTime = max(0, gapThreshold - elapsedUnmatchedTime)
        gapThresholdTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(remainingTime))
                guard let self, self.state == .listening else { return }
                self.updateElapsedDuration()
                guard
                    let unmatchedStartTime = self.unmatchedStartTime,
                    self.elapsedDuration - unmatchedStartTime >= self.gapThreshold
                else {
                    return
                }
                self.activateGapIfNeeded()
            } catch {
                return
            }
        }
    }

    private func activateGapIfNeeded() {
        guard activeGapStartTime == nil, let unmatchedStartTime else { return }
        activeGapStartTime = unmatchedStartTime
    }

    private func finishActiveGap(at endTime: TimeInterval) -> ShazamRecognitionGap? {
        guard let startTime = activeGapStartTime, endTime > startTime else { return nil }
        let gap = ShazamRecognitionGap(
            id: UUID(),
            startTime: startTime,
            endTime: endTime
        )
        activeGapStartTime = nil
        return gap
    }

    private func resetUnmatchedPeriod() {
        gapThresholdTask?.cancel()
        unmatchedStartTime = nil
        activeGapStartTime = nil
    }

    private var currentElapsedDuration: TimeInterval {
        guard let listeningStartedAt else {
            return accumulatedListeningDuration
        }
        return accumulatedListeningDuration + Date.now.timeIntervalSince(listeningStartedAt)
    }

    private func updateElapsedDuration() {
        let currentDuration = currentElapsedDuration
        if listeningStartedAt != nil {
            accumulatedListeningDuration = currentDuration
            listeningStartedAt = .now
        }
        elapsedDuration = currentDuration
    }

    private func startElapsedUpdates() {
        elapsedUpdateTask?.cancel()
        elapsedUpdateTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                    self?.updateElapsedDuration()
                } catch {
                    return
                }
            }
        }
    }
}

private extension ShazamRecognitionState {
    var hasActiveSession: Bool {
        switch self {
        case .preparing, .listening, .interrupted, .recovering:
            true
        case .idle, .paused, .microphonePermissionDenied, .failed:
            false
        }
    }
}

extension ShazamRecognitionService: SHSessionDelegate {
    nonisolated func session(_ session: SHSession, didFind match: SHMatch) {
        let callbackSessionID = ObjectIdentifier(session)
        Task { @MainActor [weak self] in
            guard
                let self,
                callbackSessionID == ObjectIdentifier(self.shazamSession),
                self.state == .listening
            else {
                return
            }
            self.accept(match: match)
        }
    }

    nonisolated func session(
        _ session: SHSession,
        didNotFindMatchFor signature: SHSignature,
        error: (any Error)?
    ) {
        let callbackSessionID = ObjectIdentifier(session)
        Task { @MainActor [weak self] in
            guard
                let self,
                callbackSessionID == ObjectIdentifier(self.shazamSession),
                self.state == .listening
            else {
                return
            }
            if error == nil {
                self.handleNoMatch()
            } else {
                self.failRecognition()
            }
        }
    }
}

private enum ShazamRecognitionError: Error {
    case unavailableAudioInput
}
