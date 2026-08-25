import SwiftUI

private struct SpotifyExportSheetModifier: ViewModifier {
    @EnvironmentObject private var spotifySession: SpotifySession
    @Environment(\.openURL) private var openURL

    @Binding var isPresented: Bool
    let playlistName: String
    let tracks: [SpotifyExportTrack]

    @State private var state: SpotifySheetState = .export
    @State private var createdPlaylist: SpotifyPlaylist?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                SpotifySheet(
                    state: displayedState,
                    playlistName: playlistName,
                    songCount: tracks.count,
                    primaryAction: primaryAction,
                    dismiss: {
                        isPresented = false
                    }
                )
                .presentationDetents([.height(398)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(SetlistColor.backgroundCanvas)
            }
            .onChange(of: isPresented) { _, isPresented in
                if isPresented {
                    state = .export
                    createdPlaylist = nil
                }
            }
    }

    private var displayedState: SpotifySheetState {
        spotifySession.isConnected ? state : .connection
    }

    private func primaryAction() {
        switch displayedState {
        case .connection:
            Task {
                await spotifySession.connect()
            }
        case .export:
            Task {
                do {
                    createdPlaylist = try await spotifySession.exportPrivatePlaylist(
                        name: playlistName,
                        tracks: tracks
                    )
                    state = .success
                } catch {
                    return
                }
            }
        case .success:
            if let url = createdPlaylist?.spotifyURL {
                openURL(url)
            }
        }
    }
}
extension View {
    func spotifyExportSheet(
        isPresented: Binding<Bool>,
        playlistName: String,
        tracks: [SpotifyExportTrack]
    ) -> some View {
        modifier(
            SpotifyExportSheetModifier(
                isPresented: isPresented,
                playlistName: playlistName,
                tracks: tracks
            )
        )
    }
}
