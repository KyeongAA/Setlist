import SwiftUI

struct SpotifyButton: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image("SpotifyLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .frame(width: 40, height: 40)
                .background(SetlistColor.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Spotify로 내보내기")
    }
}

struct SpotifyPrimaryButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .setlistTextStyle(.actionButton)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(SetlistColor.spotifyGreen)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
