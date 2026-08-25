import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class SpotifyAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let configuration: SpotifyConfiguration
    private var webAuthenticationSession: ASWebAuthenticationSession?

    init(configuration: SpotifyConfiguration) {
        self.configuration = configuration
    }

    func authorize() async throws -> SpotifyToken {
        let verifier = try Self.randomURLSafeString(byteCount: 64)
        let state = try Self.randomURLSafeString(byteCount: 24)
        let challenge = Self.codeChallenge(for: verifier)
        let authorizationURL = try makeAuthorizationURL(
            state: state,
            challenge: challenge
        )
        let callbackURL = try await openAuthorizationURL(authorizationURL)
        let code = try authorizationCode(from: callbackURL, expectedState: state)

        return try await exchangeAuthorizationCode(code, verifier: verifier)
    }

    func refresh(_ refreshToken: String) async throws -> SpotifyToken {
        let response: SpotifyTokenResponse = try await requestToken(
            parameters: [
                URLQueryItem(name: "client_id", value: configuration.clientID),
                URLQueryItem(name: "grant_type", value: "refresh_token"),
                URLQueryItem(name: "refresh_token", value: refreshToken),
            ]
        )

        return SpotifyToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: .now.addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope
        )
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        if let keyWindow = windowScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return keyWindow
        }

        guard let windowScene = windowScenes.first else {
            preconditionFailure("Spotify authentication requires an active window scene")
        }
        return ASPresentationAnchor(windowScene: windowScene)
    }

    private func makeAuthorizationURL(
        state: String,
        challenge: String
    ) throws -> URL {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
        ]

        guard let url = components?.url else {
            throw SpotifyServiceError.invalidAuthorizationURL
        }
        return url
    }

    private func openAuthorizationURL(_ url: URL) async throws -> URL {
        guard let callbackScheme = configuration.redirectURI.scheme else {
            throw SpotifyServiceError.invalidAuthorizationURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.webAuthenticationSession = nil

                if let authenticationError = error as? ASWebAuthenticationSessionError,
                   authenticationError.code == .canceledLogin {
                    continuation.resume(throwing: SpotifyServiceError.authorizationCancelled)
                } else if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: SpotifyServiceError.invalidResponse)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            webAuthenticationSession = session

            guard session.start() else {
                webAuthenticationSession = nil
                continuation.resume(throwing: SpotifyServiceError.invalidResponse)
                return
            }
        }
    }

    private func authorizationCode(
        from callbackURL: URL,
        expectedState: String
    ) throws -> String {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
        let returnedState = items?.first(where: { $0.name == "state" })?.value

        guard returnedState == expectedState else {
            throw SpotifyServiceError.authorizationStateMismatch
        }

        if let error = items?.first(where: { $0.name == "error" })?.value {
            throw SpotifyServiceError.api(statusCode: 400, message: error)
        }

        guard let code = items?.first(where: { $0.name == "code" })?.value else {
            throw SpotifyServiceError.missingAuthorizationCode
        }
        return code
    }

    private func exchangeAuthorizationCode(
        _ code: String,
        verifier: String
    ) async throws -> SpotifyToken {
        let response: SpotifyTokenResponse = try await requestToken(
            parameters: [
                URLQueryItem(name: "client_id", value: configuration.clientID),
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "code", value: code),
                URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
                URLQueryItem(name: "code_verifier", value: verifier),
            ]
        )

        return SpotifyToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: .now.addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope
        )
    }

    private func requestToken<Response: Decodable>(
        parameters: [URLQueryItem]
    ) async throws -> Response {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw SpotifyServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )

        var components = URLComponents()
        components.queryItems = parameters
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func randomURLSafeString(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else {
            throw SpotifyServiceError.invalidResponse
        }
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(SpotifyTokenErrorResponse.self, from: data))?.errorDescription
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw SpotifyServiceError.api(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }
}

private struct SpotifyTokenErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
