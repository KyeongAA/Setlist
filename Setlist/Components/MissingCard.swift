import SwiftUI

struct MissingCard: View {
    let startTime: TimeInterval
    let endTime: TimeInterval
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: SetlistSpacing.xs) {
            Text("\(timeString(startTime)) ~ \(timeString(endTime))")
                .setlistTextStyle(.bodyPrimary)
                .foregroundStyle(SetlistColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("이 구간의 음악을 정확히 확인하지 못했어요")
                .setlistTextStyle(.bodySecondary)
                .foregroundStyle(SetlistColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SmallButton(title: "곡 추가", showsPlus: true, action: action)
        }
        .padding(.horizontal, SetlistSpacing.large)
        .padding(.vertical, SetlistSpacing.small)
        .frame(width: 343)
        .background(SetlistColor.backgroundSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    init(
        startTime: TimeInterval = 20 * 60 + 14,
        endTime: TimeInterval = 20 * 60 + 21,
        action: @escaping () -> Void = {}
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.action = action
    }

    private func timeString(_ duration: TimeInterval) -> String {
        let elapsed = max(0, Int(duration))
        let hours = elapsed / 3_600
        let minutes = (elapsed % 3_600) / 60
        let seconds = elapsed % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
