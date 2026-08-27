import Combine
import Foundation

@MainActor
final class SpotifySession: ObservableObject {
    @Published private(set) var isConnected: Bool
    @Published private(set) var isConnecting = false
    @Published private(set) var lastError: Error?
    @Published private(set) var presentedAlert: SpotifyAlertPresentation?

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
            present(error, for: .connection)
        }
    }

    func searchTracks(
        query: String,
        limit: Int = 8,
        offset: Int = 0
    ) async throws -> [SpotifyTrack] {
        do {
            let accessToken = try await validAccessToken()
            return try await apiClient.searchTracks(
                query: query,
                accessToken: accessToken,
                limit: limit,
                offset: offset
            )
        } catch {
            guard !Task.isCancelled else { throw CancellationError() }
            present(error, for: .search)
            throw error
        }
    }

    func exportPrivatePlaylist(
        name: String,
        tracks: [SpotifyExportTrack]
    ) async throws -> SpotifyPlaylist {
        do {
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
        } catch {
            guard !Task.isCancelled else { throw CancellationError() }
            present(error, for: .export)
            throw error
        }
    }

    func disconnect() {
        do {
            try tokenStore.delete()
            token = nil
            isConnected = false
            lastError = nil
            presentedAlert = nil
        } catch {
            present(error, for: .disconnection)
        }
    }

    func dismissAlert() {
        presentedAlert = nil
        lastError = nil
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

    private func present(
        _ error: Error,
        for operation: SpotifyOperation
    ) {
        lastError = error
        presentedAlert = SpotifyAlertPresentation(
            title: operation.failureTitle,
            message: userFacingMessage(for: error)
        )
    }

    private func userFacingMessage(for error: Error) -> String {
        guard let spotifyError = error as? SpotifyServiceError else {
            return error.localizedDescription
        }

        if case let .api(statusCode, message) = spotifyError {
            switch statusCode {
            case 401:
                return "Spotify 인증이 만료됐습니다. 계정을 다시 연결해주세요."
            case 403:
                return "Spotify 개발자 모드 접근 권한이 거부됐습니다. 앱 소유자의 Premium 구독과 Dashboard의 허용 사용자를 확인해주세요.\n\nSpotify 응답: \(message)"
            case 429:
                return "Spotify 요청이 너무 많습니다. 잠시 후 다시 시도해주세요."
            default:
                return "Spotify 응답(\(statusCode)): \(message)"
            }
        }

        return spotifyError.localizedDescription
    }
}

struct SpotifyAlertPresentation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

private enum SpotifyOperation {
    case connection
    case search
    case export
    case disconnection

    var failureTitle: String {
        switch self {
        case .connection:
            "음악 플랫폼을 연결하지 못했어요"
        case .search:
            "곡을 검색하지 못했어요"
        case .export:
            "플레이리스트를 만들지 못했어요"
        case .disconnection:
            "음악 플랫폼 연결을 해제하지 못했어요"
        }
    }
}
