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
    case listening
    case paused
    case microphonePermissionDenied
    case failed
}

@MainActor
final class ShazamRecognitionService: NSObject, ObservableObject {
    @Published private(set) var state: ShazamRecognitionState = .idle
    @Published private(set) var latestMatch: ShazamRecognizedTrack?
    @Published private(set) var latestGap: ShazamRecognitionGap?
    @Published private(set) var elapsedDuration: TimeInterval = 0
    @Published private(set) var activeGapStartTime: TimeInterval?

    private var audioEngine = AVAudioEngine()
    private var mixerNode = AVAudioMixerNode()
    private var shazamSession = SHSession()
    private var isAudioEngineConfigured = false
    private var lastMatchID: String?
    private var lastMatchDate: Date?
    private let gapThreshold: TimeInterval
    private var accumulatedListeningDuration: TimeInterval = 0
    private var listeningStartedAt: Date?
    private var unmatchedStartTime: TimeInterval?
    private var gapThresholdTask: Task<Void, Never>?
    private var elapsedUpdateTask: Task<Void, Never>?

    init(gapThreshold: TimeInterval = 180) {
        self.gapThreshold = gapThreshold
        super.init()
        shazamSession.delegate = self
    }

    func restoreElapsedDuration(_ duration: TimeInterval) {
        guard state == .idle, listeningStartedAt == nil else { return }
        accumulatedListeningDuration = max(0, duration)
        elapsedDuration = accumulatedListeningDuration
    }

    func start() async {
        guard state != .listening else { return }

        let permissionGranted = await AVAudioApplication.requestRecordPermission()
        guard permissionGranted else {
            state = .microphonePermissionDenied
            return
        }

        do {
            try configureAudioSession()
            try rebuildRecognitionPipeline()
            audioEngine.prepare()
            try audioEngine.start()
            listeningStartedAt = .now
            state = .listening
            startElapsedUpdates()
            scheduleGapThresholdIfNeeded()
        } catch {
            tearDownRecognitionPipeline()
            deactivateAudioSession()
            state = .failed
        }
    }

    func toggleListening() async {
        switch state {
        case .listening:
            updateElapsedDuration()
            listeningStartedAt = nil
            elapsedUpdateTask?.cancel()
            gapThresholdTask?.cancel()
            state = .paused
            tearDownRecognitionPipeline()
            deactivateAudioSession()
        case .paused, .idle, .failed:
            await start()
        case .microphonePermissionDenied:
            return
        }
    }

    @discardableResult
    func stop() -> ShazamRecognitionGap? {
        updateElapsedDuration()
        listeningStartedAt = nil
        elapsedUpdateTask?.cancel()
        gapThresholdTask?.cancel()

        var completedGap: ShazamRecognitionGap?
        if let unmatchedStartTime,
           elapsedDuration - unmatchedStartTime >= gapThreshold {
            activateGapIfNeeded()
            completedGap = finishActiveGap(at: elapsedDuration, publish: false)
        }
        resetUnmatchedPeriod()

        tearDownRecognitionPipeline()
        deactivateAudioSession()
        state = .idle
        return completedGap
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker]
        )
        try audioSession.setActive(true)
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
        ) { buffer, audioTime in
            session.matchStreamingBuffer(buffer, at: audioTime)
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
        _ = finishActiveGap(at: recognitionTime)
        resetUnmatchedPeriod()

        let now = Date.now
        let matchID = item.shazamID ?? "\(title)|\(artistName)"
        if lastMatchID == matchID,
           let lastMatchDate,
           now.timeIntervalSince(lastMatchDate) < 60 {
            return
        }

        lastMatchID = matchID
        lastMatchDate = now
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

    private func finishActiveGap(
        at endTime: TimeInterval,
        publish: Bool = true
    ) -> ShazamRecognitionGap? {
        guard let startTime = activeGapStartTime, endTime > startTime else { return nil }
        let gap = ShazamRecognitionGap(
            id: UUID(),
            startTime: startTime,
            endTime: endTime
        )
        if publish {
            latestGap = gap
        }
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

extension ShazamRecognitionService: SHSessionDelegate {
    nonisolated func session(_ session: SHSession, didFind match: SHMatch) {
        Task { @MainActor [weak self] in
            guard
                let self,
                session === self.shazamSession,
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
        Task { @MainActor [weak self] in
            guard
                let self,
                session === self.shazamSession,
                self.state == .listening
            else {
                return
            }
            if error == nil {
                self.handleNoMatch()
            } else {
                self.tearDownRecognitionPipeline()
                self.deactivateAudioSession()
                self.state = .failed
            }
        }
    }
}

private enum ShazamRecognitionError: Error {
    case unavailableAudioInput
}
