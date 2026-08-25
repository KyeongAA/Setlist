import Foundation

struct SpotifyTrack: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let uri: String
    let durationMilliseconds: Int
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    let externalIDs: SpotifyExternalIDs?

    var artistName: String {
        artists.map(\.name).joined(separator: ", ")
    }

    var artworkURLString: String? {
        album.images.first?.url
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case uri
        case durationMilliseconds = "duration_ms"
        case artists
        case album
        case externalIDs = "external_ids"
    }
}

struct SpotifyArtist: Decodable, Hashable, Sendable {
    let name: String
}

struct SpotifyAlbum: Decodable, Hashable, Sendable {
    let name: String
    let images: [SpotifyImage]
}

struct SpotifyImage: Decodable, Hashable, Sendable {
    let url: String
    let width: Int?
    let height: Int?
}

struct SpotifyExternalIDs: Decodable, Hashable, Sendable {
    let isrc: String?
}

struct SpotifyExportTrack: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let artistName: String
    let spotifyURI: String?
    let isrc: String?
}

struct SpotifyPlaylist: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let uri: String
    let externalURLs: SpotifyExternalURLs

    var spotifyURL: URL? {
        URL(string: externalURLs.spotify)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case uri
        case externalURLs = "external_urls"
    }
}

struct SpotifyExternalURLs: Decodable, Sendable {
    let spotify: String
}

struct SpotifyToken: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scope: String?

    var needsRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }
}

struct SpotifyTokenResponse: Decodable, Sendable {
    let accessToken: String
    let tokenType: String
    let scope: String?
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

enum SpotifyServiceError: LocalizedError {
    case invalidAuthorizationURL
    case authorizationCancelled
    case authorizationStateMismatch
    case missingAuthorizationCode
    case invalidResponse
    case unresolvedTrack(title: String)
    case api(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidAuthorizationURL:
            "Spotify 로그인 주소를 만들 수 없습니다."
        case .authorizationCancelled:
            "Spotify 연결이 취소되었습니다."
        case .authorizationStateMismatch:
            "Spotify 로그인 요청을 확인할 수 없습니다."
        case .missingAuthorizationCode:
            "Spotify 로그인 결과에 인증 코드가 없습니다."
        case .invalidResponse:
            "Spotify 응답을 확인할 수 없습니다."
        case let .unresolvedTrack(title):
            "\(title)의 Spotify 곡을 확인할 수 없습니다."
        case let .api(_, message):
            message
        }
    }
}

extension SpotifyTrack {
    static let previewTracks: [SpotifyTrack] = [
        SpotifyTrack(
            id: "preview-1",
            name: "Supernova",
            uri: "spotify:track:preview-1",
            durationMilliseconds: 178_880,
            artists: [SpotifyArtist(name: "aespa")],
            album: SpotifyAlbum(name: "Armageddon", images: []),
            externalIDs: nil
        ),
        SpotifyTrack(
            id: "preview-2",
            name: "Whiplash",
            uri: "spotify:track:preview-2",
            durationMilliseconds: 183_040,
            artists: [SpotifyArtist(name: "aespa")],
            album: SpotifyAlbum(name: "Whiplash", images: []),
            externalIDs: nil
        ),
    ]
}
