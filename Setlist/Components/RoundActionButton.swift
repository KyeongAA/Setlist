import SwiftUI

enum RoundActionIcon {
    case microphone
    case pause
    case checkmark

    @ViewBuilder
    var image: some View {
        switch self {
        case .microphone:
            Image("IconMicrophone")
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 25)
        case .pause:
            Image("IconPause")
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 18)
        case .checkmark:
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(SetlistColor.iconInverse)
        }
    }
}

struct RoundActionButton: View {
    let icon: RoundActionIcon
    var size: CGFloat = 68
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            icon.image
                .frame(width: size, height: size)
                .background(SetlistColor.brandPrimary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
