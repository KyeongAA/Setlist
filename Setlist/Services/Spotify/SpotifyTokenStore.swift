import Foundation
import Security

final class SpotifyTokenStore: @unchecked Sendable {
    private let service: String
    private let account = "spotify-oauth-token"

    init(bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.Phoebe.Setlist") {
        service = "\(bundleIdentifier).spotify"
    }

    func load() -> SpotifyToken? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data
        else {
            return nil
        }

        return try? JSONDecoder().decode(SpotifyToken.self, from: data)
    }

    func save(_ token: SpotifyToken) throws {
        let data = try JSONEncoder().encode(token)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(
            baseQuery as CFDictionary,
            attributes as CFDictionary
        )

        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SpotifyKeychainError.unhandledStatus(addStatus)
            }
        } else if status != errSecSuccess {
            throw SpotifyKeychainError.unhandledStatus(status)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SpotifyKeychainError.unhandledStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
    }
}

private enum SpotifyKeychainError: Error {
    case unhandledStatus(OSStatus)
}
