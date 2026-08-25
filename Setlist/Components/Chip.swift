import SwiftUI

struct Chip: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .setlistTextStyle(.bodySecondary)
                .foregroundStyle(SetlistColor.textInverse)
                .padding(.horizontal, SetlistSpacing.medium)
                .frame(height: 36)
                .background(SetlistColor.backgroundInverse)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
