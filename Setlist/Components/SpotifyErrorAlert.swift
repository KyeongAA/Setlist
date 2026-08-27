import SwiftUI

private struct SpotifyErrorAlertModifier: ViewModifier {
    @EnvironmentObject private var spotifySession: SpotifySession

    private var presentedAlert: Binding<SpotifyAlertPresentation?> {
        Binding(
            get: { spotifySession.presentedAlert },
            set: { alert in
                if alert == nil {
                    spotifySession.dismissAlert()
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(item: presentedAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("확인")) {
                        spotifySession.dismissAlert()
                    }
                )
            }
    }
}

extension View {
    func spotifyErrorAlert() -> some View {
        modifier(SpotifyErrorAlertModifier())
    }
}
