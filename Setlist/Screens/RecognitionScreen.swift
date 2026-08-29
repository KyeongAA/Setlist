import SwiftUI
import UIKit

private enum RecognitionAlert: Identifiable, Hashable {
    case microphonePermissionDenied
    case failed

    var id: Self { self }
}

struct RecognitionScreen: View {
    @Environment(\.openURL) private var openURL
    @State private var isSearchPresented = false
    @State private var isEndConfirmationPresented = false
    @State private var recognitionAlert: RecognitionAlert?
    @ObservedObject var recognizer: ShazamRecognitionService

    var initialRecognitionDuration: TimeInterval = 0
    var songs: [SetlistSong] = SetlistSong.sampleSongs
    var recognitionGaps: [SetlistRecognitionGap] = []
    var addSong: () -> Void = {}
    var addSpotifyTrack: (SpotifyTrack) -> Void = { _ in }
    var deleteSong: (SetlistSong) -> Void = { _ in }
    var moveSongs: ([SetlistSong], IndexSet, Int) -> Void = { _, _, _ in }
    var recognizedGap: (ShazamRecognitionGap) -> Void = { _ in }
    var updateRecognitionDuration: (TimeInterval) -> Void = { _ in }
    var toggleListening: () -> Void = {}
    var endRecognition: () -> Void = {}
    var automaticallyStartsRecognition = true

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: 0) {
                SheetHandle()
                    .padding(.top, SetlistSpacing.xs)

                Text(recognitionStatusText)
                    .setlistTextStyle(.utilityStatus)
                    .foregroundStyle(recognitionStatusColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 26)

                RecognitionTimelineList(
                    songs: songs,
                    gaps: recognitionGaps,
                    activeGapStartTime: recognizer.activeGapStartTime,
                    activeGapEndTime: recognizer.elapsedDuration,
                    fillsAvailableHeight: true,
                    automaticallyScrollsToLatest: true,
                    gapAction: presentSearch,
                    deleteSong: deleteSong,
                    moveSongs: moveSongs
                ) {
                    recognitionListFooter
                }
                .padding(.top, SetlistSpacing.large)
            }
            .padding(.horizontal, SetlistSpacing.large)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActions
                .padding(.horizontal, SetlistSpacing.large)
                .padding(.top, SetlistSpacing.extraLarge)
                .padding(.bottom, SetlistSpacing.xs)
        }
        .searchSheet(
            isPresented: $isSearchPresented,
            addSpotifyTrack: addSpotifyTrack
        )
        .alert("공연 인식을 종료할까요?", isPresented: $isEndConfirmationPresented) {
            Button("취소", role: .cancel) {}
            Button("종료", role: .destructive) {
                if let gap = recognizer.stop() {
                    recognizedGap(gap)
                }
                updateRecognitionDuration(recognizer.elapsedDuration)
                endRecognition()
            }
        }
        .alert(item: $recognitionAlert) { alert in
            switch alert {
            case .microphonePermissionDenied:
                Alert(
                    title: Text("마이크 권한이 필요해요"),
                    message: Text(
                        "설정에서 마이크 접근을 허용하면 음악 인식을 시작할 수 있어요."
                    ),
                    primaryButton: .default(Text("설정 열기")) {
                        guard let settingsURL = URL(
                            string: UIApplication.openSettingsURLString
                        ) else {
                            return
                        }
                        openURL(settingsURL)
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            case .failed:
                Alert(
                    title: Text("음악 인식을 시작할 수 없어요"),
                    message: Text("오디오 연결을 확인한 뒤 다시 시도해 주세요."),
                    primaryButton: .default(Text("다시 시도")) {
                        Task {
                            await recognizer.start()
                        }
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            }
        }
        .task {
            guard automaticallyStartsRecognition else { return }
            if recognizer.state == .idle {
                recognizer.restoreElapsedDuration(initialRecognitionDuration)
                await recognizer.start()
            }
        }
        .onDisappear {
            updateRecognitionDuration(recognizer.elapsedDuration)
        }
        .onChange(of: recognizer.state) { _, state in
            switch state {
            case .microphonePermissionDenied:
                recognitionAlert = .microphonePermissionDenied
            case .failed:
                recognitionAlert = .failed
            default:
                break
            }
        }
    }

    private func presentSearch() {
        isSearchPresented = true
        addSong()
    }

    private func toggleRecognition() {
        Task {
            await recognizer.toggleListening()
            updateRecognitionDuration(recognizer.elapsedDuration)
            toggleListening()
        }
    }

    private var recognitionListFooter: some View {
        VStack(spacing: SetlistSpacing.large) {
            ListeningWaveform(isAnimating: recognizer.state == .listening)

            SmallButton(title: "곡 추가", showsPlus: true, action: presentSearch)
        }
        .padding(.top, SetlistSpacing.xs)
        .padding(.bottom, SetlistSpacing.large)
    }

    private var bottomActions: some View {
        ZStack {
            RoundActionButton(
                icon: showsPauseAction ? .pause : .microphone,
                size: 64,
                action: toggleRecognition
            )

            HStack {
                Spacer()

                Button {
                    isEndConfirmationPresented = true
                } label: {
                    Text("종료")
                        .setlistTextStyle(.actionButton)
                        .foregroundStyle(SetlistColor.textPrimary)
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("공연 인식 종료")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var recognitionStatusText: String {
        let elapsed = elapsedTimeString(recognizer.elapsedDuration)

        switch recognizer.state {
        case .idle, .preparing:
            return "인식을 준비하고 있어요  ·  \(elapsed)"
        case .listening:
            if recognizer.activeGapStartTime != nil {
                return "인식 불안정 구간  ·  \(elapsed)"
            }
            return "인식 중  ·  \(elapsed)"
        case .paused:
            return "인식을 일시정지했어요  ·  \(elapsed)"
        case .interrupted:
            return "다른 오디오 사용으로 잠시 중단됐어요  ·  \(elapsed)"
        case .recovering:
            return "인식을 다시 연결하고 있어요  ·  \(elapsed)"
        case .microphonePermissionDenied:
            return "마이크 권한이 필요해요  ·  \(elapsed)"
        case .failed:
            return "음악 인식을 시작할 수 없어요  ·  \(elapsed)"
        }
    }

    private var recognitionStatusColor: Color {
        switch recognizer.state {
        case .listening where recognizer.activeGapStartTime != nil:
            SetlistColor.semanticWarningContent
        case .listening:
            SetlistColor.semanticSuccessContent
        case .microphonePermissionDenied, .failed:
            SetlistColor.semanticErrorContent
        case .idle, .preparing, .paused, .interrupted, .recovering:
            SetlistColor.textSecondary
        }
    }

    private var showsPauseAction: Bool {
        switch recognizer.state {
        case .preparing, .listening, .interrupted, .recovering:
            true
        case .idle, .paused, .microphonePermissionDenied, .failed:
            false
        }
    }

    private func elapsedTimeString(_ duration: TimeInterval) -> String {
        let elapsed = max(0, Int(duration))
        let hours = elapsed / 3_600
        let minutes = (elapsed % 3_600) / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview("Recognition") {
    RecognitionScreen(
        recognizer: ShazamRecognitionService(),
        automaticallyStartsRecognition: false
    )
        .environmentObject(SpotifySession())
}
