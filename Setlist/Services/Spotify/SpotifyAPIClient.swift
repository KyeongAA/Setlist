import Foundation

struct SpotifyAPIClient: Sendable {
    func searchTracks(
        query: String,
        accessToken: String,
        limit: Int = 8,
        offset: Int = 0
    ) async throws -> [SpotifyTrack] {
        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        guard let url = components?.url else {
            throw SpotifyServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SpotifySearchResponse.self, from: data).tracks.items
    }

    func track(isrc: String, accessToken: String) async throws -> SpotifyTrack? {
        try await searchTracks(
            query: "isrc:\(isrc)",
            accessToken: accessToken,
            limit: 1
        ).first
    }

    func createPrivatePlaylist(
        name: String,
        accessToken: String
    ) async throws -> SpotifyPlaylist {
        guard let url = URL(string: "https://api.spotify.com/v1/me/playlists") else {
            throw SpotifyServiceError.invalidResponse
        }

        var request = authorizedRequest(url: url, accessToken: accessToken)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            CreatePlaylistRequest(
                name: name,
                isPublic: false,
                description: "Setlist에서 기록한 공연 셋리스트"
            )
        )

        let data = try await responseData(for: request)
        return try JSONDecoder().decode(SpotifyPlaylist.self, from: data)
    }

    func addItems(
        uris: [String],
        to playlistID: String,
        accessToken: String
    ) async throws {
        guard let url = URL(
            string: "https://api.spotify.com/v1/playlists/\(playlistID)/items"
        ) else {
            throw SpotifyServiceError.invalidResponse
        }

        for batch in uris.chunked(into: 100) {
            var request = authorizedRequest(url: url, accessToken: accessToken)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AddPlaylistItemsRequest(uris: batch))
            _ = try await responseData(for: request)
        }
    }

    private func authorizedRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(SpotifyAPIErrorEnvelope.self, from: data))?.error.message
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw SpotifyServiceError.api(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }
}

private struct CreatePlaylistRequest: Encodable {
    let name: String
    let isPublic: Bool
    let description: String

    enum CodingKeys: String, CodingKey {
        case name
        case isPublic = "public"
        case description
    }
}

private struct AddPlaylistItemsRequest: Encodable {
    let uris: [String]
}

private struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyTrackPage
}

private struct SpotifyTrackPage: Decodable {
    let items: [SpotifyTrack]
}

private struct SpotifyAPIErrorEnvelope: Decodable {
    let error: SpotifyAPIError
}

private struct SpotifyAPIError: Decodable {
    let status: Int
    let message: String
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
