import SwiftUI

enum MiniBarState {
    case listening
    case paused
    case start

    var title: String {
        switch self {
        case .listening: "음악을 인식 중이에요"
        case .paused: "일시정지 중"
        case .start: "새로운 셋리스트를 기록하세요"
        }
    }

    var iconName: String {
        switch self {
        case .listening: "IconPause"
        case .paused, .start: "IconMicrophone"
        }
    }
}

struct MiniBar: View {
    let state: MiniBarState
    var action: () -> Void = {}
    var expandAction: () -> Void = {}

    var body: some View {
        HStack {
            Text(state.title)
                .setlistTextStyle(.utilityStatus)
                .foregroundStyle(SetlistColor.textPrimary)

            Spacer(minLength: SetlistSpacing.small)

            Button(action: action) {
                Image(state.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: state == .listening ? 12 : 17,
                        height: state == .listening ? 18 : 25
                    )
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state == .listening ? "일시정지" : "인식 시작")
        }
        .padding(.leading, SetlistSpacing.medium)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(SetlistColor.backgroundMinibar)
        .clipShape(RoundedRectangle(cornerRadius: SetlistRadius.medium))
        .overlay(alignment: .top) {
            Capsule()
                .fill(SetlistColor.textTertiary)
                .frame(width: 28, height: 2)
                .padding(.top, 4)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    guard
                        value.translation.height < -24,
                        abs(value.translation.height) > abs(value.translation.width)
                    else {
                        return
                    }
                    expandAction()
                }
        )
        .accessibilityAction(named: "인식 화면 열기", expandAction)
        .padding(.horizontal, SetlistMargin.medium)
    }
}

#Preview("Mini bar states") {
    VStack(spacing: 30) {
        MiniBar(state: .listening)
        MiniBar(state: .paused)
        MiniBar(state: .start)
    }
    .padding()
    .background(SetlistColor.backgroundCanvas)
    .preferredColorScheme(.dark)
}
