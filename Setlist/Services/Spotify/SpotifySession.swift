import Combine
import Foundation

@MainActor
final class SpotifySession: ObservableObject {
    @Published private(set) var isConnected: Bool
    @Published private(set) var isConnecting = false
    @Published private(set) var lastError: Error?

    private let authService: SpotifyAuthService
    private let apiClient: SpotifyAPIClient
    private let tokenStore: SpotifyTokenStore
    private var token: SpotifyToken?

    init() {
        let configuration = SpotifyConfiguration.current
        let apiClient = SpotifyAPIClient()
        let tokenStore = SpotifyTokenStore()

        self.authService = SpotifyAuthService(configuration: configuration)
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        let storedToken = tokenStore.load()
        self.token = storedToken
        self.isConnected = storedToken != nil
    }

    func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        lastError = nil
        defer { isConnecting = false }

        do {
            let token = try await authService.authorize()
            try tokenStore.save(token)
            self.token = token
            isConnected = true
        } catch SpotifyServiceError.authorizationCancelled {
            return
        } catch {
            lastError = error
        }
    }

    func searchTracks(
        query: String,
        limit: Int = 8,
        offset: Int = 0
    ) async throws -> [SpotifyTrack] {
        let accessToken = try await validAccessToken()
        return try await apiClient.searchTracks(
            query: query,
            accessToken: accessToken,
            limit: limit,
            offset: offset
        )
    }

    func exportPrivatePlaylist(
        name: String,
        tracks: [SpotifyExportTrack]
    ) async throws -> SpotifyPlaylist {
        let accessToken = try await validAccessToken()
        var uris: [String] = []

        for track in tracks {
            if let spotifyURI = track.spotifyURI {
                uris.append(spotifyURI)
            } else if let isrc = track.isrc,
                      let spotifyTrack = try await apiClient.track(
                        isrc: isrc,
                        accessToken: accessToken
                      ) {
                uris.append(spotifyTrack.uri)
            } else {
                throw SpotifyServiceError.unresolvedTrack(title: track.title)
            }
        }

        let playlist = try await apiClient.createPrivatePlaylist(
            name: name,
            accessToken: accessToken
        )
        try await apiClient.addItems(
            uris: uris,
            to: playlist.id,
            accessToken: accessToken
        )
        return playlist
    }

    func disconnect() {
        do {
            try tokenStore.delete()
            token = nil
            isConnected = false
            lastError = nil
        } catch {
            lastError = error
        }
    }

    private func validAccessToken() async throws -> String {
        guard let token else {
            throw SpotifyServiceError.authorizationCancelled
        }
        guard token.needsRefresh else {
            return token.accessToken
        }
        guard let refreshToken = token.refreshToken else {
            self.token = nil
            isConnected = false
            throw SpotifyServiceError.authorizationCancelled
        }

        let refreshedToken = try await authService.refresh(refreshToken)
        try tokenStore.save(refreshedToken)
        self.token = refreshedToken
        return refreshedToken.accessToken
    }
}
