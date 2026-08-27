import SwiftUI

private struct SearchSheetModifier: ViewModifier {
    @EnvironmentObject private var spotifySession: SpotifySession

    @Binding var isPresented: Bool
    let state: SetlistSearchScreenState
    let addSpotifyTrack: (SpotifyTrack) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                Group {
                    if spotifySession.isConnected {
                        SearchScreen(
                            state: state,
                            searchTracks: { query, limit, offset in
                                try await spotifySession.searchTracks(
                                    query: query,
                                    limit: limit,
                                    offset: offset
                                )
                            },
                            addSpotifyTrack: { track in
                                addSpotifyTrack(track)
                                isPresented = false
                            }
                        )
                    } else {
                        SpotifySheet(
                            state: .connection,
                            primaryAction: {
                                Task {
                                    await spotifySession.connect()
                                }
                            }
                        )
                    }
                }
                .spotifyErrorAlert()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
                .presentationBackground(SetlistColor.backgroundCanvas)
            }
    }
}

extension View {
    func searchSheet(
        isPresented: Binding<Bool>,
        state: SetlistSearchScreenState = .recent,
        addSpotifyTrack: @escaping (SpotifyTrack) -> Void = { _ in }
    ) -> some View {
        modifier(
            SearchSheetModifier(
                isPresented: isPresented,
                state: state,
                addSpotifyTrack: addSpotifyTrack
            )
        )
    }
}
