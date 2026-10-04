import Foundation
import Security

/// Where the server address and API token live, shared with the widget and
/// notification extensions through the `group.org.elabx.fusionha` App Group.
/// The token goes in the Keychain using the App Group as its access group (no team
/// prefix needed, so it survives re-signing with any team in Feather).
public struct Credentials: Codable, Sendable, Equatable {
    public var serverURL: URL
    public var token: String
    public var tokenId: Int?
    public var method: AuthMethod

    public init(serverURL: URL, token: String, tokenId: Int?, method: AuthMethod = .apiToken) {
        self.serverURL = serverURL
        self.token = token
        self.tokenId = tokenId
        self.method = method
    }

    public func client() -> APIClient {
        APIClient(baseURL: serverURL, token: token, method: method)
    }
}

public enum CredentialStore {
    public static let appGroup = "group.org.elabx.fusionha"
    private static let service = "org.elabx.fusionha.api-token"
    private static let serverKey = "serverURL"
    private static let tokenIdKey = "tokenId"
    private static let methodKey = "authMethod"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    public static func load() -> Credentials? {
        guard let raw = defaults.string(forKey: serverKey), let url = URL(string: raw),
              let token = readToken() else { return nil }
        let id = defaults.object(forKey: tokenIdKey) as? Int
        let method = defaults.string(forKey: methodKey).flatMap(AuthMethod.init(rawValue:)) ?? .apiToken
        return Credentials(serverURL: url, token: token, tokenId: id, method: method)
    }

    public static func save(_ credentials: Credentials) {
        defaults.set(credentials.serverURL.absoluteString, forKey: serverKey)
        defaults.set(credentials.tokenId, forKey: tokenIdKey)
        defaults.set(credentials.method.rawValue, forKey: methodKey)
        writeToken(credentials.token)
    }

    public static func clear() {
        defaults.removeObject(forKey: serverKey)
        defaults.removeObject(forKey: tokenIdKey)
        defaults.removeObject(forKey: methodKey)
        SecItemDelete(baseQuery() as CFDictionary)
    }

    public static func client() -> APIClient? {
        load()?.client()
    }

    // MARK: Keychain

    private static func baseQuery() -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        #if os(iOS)
        q[kSecAttrAccessGroup as String] = appGroup
        #endif
        return q
    }

    private static func readToken() -> String? {
        var q = baseQuery()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeToken(_ token: String) {
        SecItemDelete(baseQuery() as CFDictionary)
        var q = baseQuery()
        q[kSecValueData as String] = Data(token.utf8)
        // Widgets refresh while the phone is locked.
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }
}
