import SwiftUI

struct SmallButton: View {
    let title: String
    var showsPlus = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            SmallButtonLabel(title: title, showsPlus: showsPlus)
        }
        .buttonStyle(.plain)
    }
}

struct SmallButtonLabel: View {
    let title: String
    var showsPlus = false

    var body: some View {
        HStack(spacing: SetlistSpacing.xxs) {
            if showsPlus {
                Image("IconPlus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }

            Text(title)
                .setlistTextStyle(.actionButton)
                .foregroundStyle(SetlistColor.textPrimary)
        }
        .padding(.horizontal, SetlistSpacing.small)
        .padding(.vertical, SetlistSpacing.xs)
        .background(SetlistColor.backgroundSubtle)
        .overlay {
            Capsule()
                .stroke(SetlistColor.borderDefault, lineWidth: 1)
        }
        .clipShape(Capsule())
    }
}
