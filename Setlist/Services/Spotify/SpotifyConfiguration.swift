import Foundation

struct SpotifyConfiguration: Sendable {
    let clientID: String
    let redirectURI: URL
    let scopes: [String]

    static let current: SpotifyConfiguration = {
        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String,
            !clientID.isEmpty,
            let redirectURIString = Bundle.main.object(forInfoDictionaryKey: "SpotifyRedirectURI") as? String,
            let redirectURI = URL(string: redirectURIString)
        else {
            preconditionFailure("Spotify configuration is missing from Info.plist")
        }

        return SpotifyConfiguration(
            clientID: clientID,
            redirectURI: redirectURI,
            scopes: ["playlist-modify-private", "user-read-private"]
        )
    }()
}
