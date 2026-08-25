import SwiftUI

enum SetlistHomeState {
    case empty
    case recorded
}

struct HomeScreen: View {
    @State private var concertPendingDeletion: SetlistConcert? = nil

    let state: SetlistHomeState
    var concerts: [SetlistConcert] = SetlistConcert.samples
    var activeRecognitionState: MiniBarState?
    var startRecognition: () -> Void = {}
    var toggleRecognition: () -> Void = {}
    var openRecognition: () -> Void = {}
    var openConcert: (SetlistConcert) -> Void = { _ in }
    var deleteConcert: (SetlistConcert) -> Void = { _ in }

    var body: some View {
        ZStack {
            ScreenBackground()

            switch state {
            case .empty:
                emptyContent
            case .recorded:
                recordedContent
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let activeRecognitionState {
                MiniBar(
                    state: activeRecognitionState,
                    action: toggleRecognition,
                    expandAction: openRecognition
                )
            } else {
                MiniBar(
                    state: .start,
                    action: startRecognition
                )
            }
        }
        .alert(item: $concertPendingDeletion) { concert in
            Alert(
                title: Text("'\(concert.title)'을 삭제할까요?"),
                primaryButton: .destructive(Text("삭제")) {
                    deleteConcert(concert)
                },
                secondaryButton: .cancel(Text("취소"))
            )
        }
        .preferredColorScheme(.dark)
    }

    private var emptyContent: some View {
        VStack(spacing: 0) {
            Text("공연이 시작됐나요?")
                .setlistTextStyle(.headingSection)
                .foregroundStyle(SetlistColor.textPrimary)

            Text("나의 첫 셋리스트 기록을 시작하세요!")
                .setlistTextStyle(.headingSection)
                .foregroundStyle(SetlistColor.textPrimary)
                .padding(.top, SetlistSpacing.medium)

            RoundActionButton(
                icon: .microphone,
                size: 68,
                action: startRecognition
            )
            .padding(.top, 56)

            Spacer(minLength: 0)
        }
        .padding(.top, 180)
        .frame(maxWidth: .infinity)
    }

    private var recordedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("나의 공연")
                .setlistTextStyle(.headingTitle)
                .foregroundStyle(SetlistColor.textPrimary)
                .padding(.leading, SetlistSpacing.xxs)

            List {
                ForEach(concerts) { concert in
                    ConcertRow(concert: concert) {
                        openConcert(concert)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            concertPendingDeletion = concert
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(SetlistSpacing.xxs)
            .scrollContentBackground(.hidden)
            .padding(.top, SetlistSpacing.large)
        }
        .padding(.horizontal, SetlistSpacing.medium)
        .padding(.top, SetlistSpacing.large)
    }
}

#Preview("Home · Empty") {
    HomeScreen(state: .empty)
}

#Preview("Home · Recorded") {
    HomeScreen(state: .recorded)
}
