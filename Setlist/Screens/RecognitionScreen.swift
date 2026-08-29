import SwiftUI

struct RecognitionScreen: View {
    @State private var isSearchPresented = false
    @State private var isEndConfirmationPresented = false
    @ObservedObject var recognizer: ShazamRecognitionService

    var initialRecognitionDuration: TimeInterval = 0
    var songs: [SetlistSong] = SetlistSong.sampleSongs
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

                Text("인식 중  ·  \(elapsedTimeString(recognizer.elapsedDuration))")
                    .setlistTextStyle(.utilityStatus)
                    .foregroundStyle(SetlistColor.semanticSuccessContent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 26)

                EditableSongList(
                    songs: songs,
                    fillsAvailableHeight: true,
                    automaticallyScrollsToLatest: true,
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
            if let gapStartTime = recognizer.activeGapStartTime {
                MissingCard(
                    startTime: gapStartTime,
                    endTime: recognizer.elapsedDuration,
                    action: presentSearch
                )
            }

            ListeningWaveform(isAnimating: recognizer.state == .listening)

            SmallButton(title: "곡 추가", showsPlus: true, action: presentSearch)
        }
        .padding(.top, SetlistSpacing.xs)
        .padding(.bottom, SetlistSpacing.large)
    }

    private var bottomActions: some View {
        ZStack {
            RoundActionButton(
                icon: recognizer.state == .listening ? .pause : .microphone,
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
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("공연 인식 종료")
            }
        }
        .frame(maxWidth: .infinity)
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
