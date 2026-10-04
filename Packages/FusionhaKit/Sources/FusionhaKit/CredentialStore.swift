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

    /// The shared App Group store, plus the app's own store as a fallback: when a
    /// re-signed build's profile lacks the App Group, writes to the group can be
    /// lost, and the user would be signed out on every launch.
    private static var stores: [UserDefaults] {
        [UserDefaults(suiteName: appGroup), .standard].compactMap { $0 }
    }

    private static func value<T>(_ key: String, as: T.Type) -> T? {
        for store in stores { if let v = store.object(forKey: key) as? T { return v } }
        return nil
    }

    public static func load() -> Credentials? {
        guard let raw = value(serverKey, as: String.self), let url = URL(string: raw),
              let token = readToken() else { return nil }
        let id = value(tokenIdKey, as: Int.self)
        let method = value(methodKey, as: String.self).flatMap(AuthMethod.init(rawValue:)) ?? .apiToken
        return Credentials(serverURL: url, token: token, tokenId: id, method: method)
    }

    public static func save(_ credentials: Credentials) {
        for store in stores {
            store.set(credentials.serverURL.absoluteString, forKey: serverKey)
            store.set(credentials.tokenId, forKey: tokenIdKey)
            store.set(credentials.method.rawValue, forKey: methodKey)
        }
        writeToken(credentials.token)
    }

    public static func clear() {
        for store in stores {
            store.removeObject(forKey: serverKey)
            store.removeObject(forKey: tokenIdKey)
            store.removeObject(forKey: methodKey)
        }
        for query in queries { SecItemDelete(query as CFDictionary) }
    }

    /// Where the sign-in actually landed, for the avatar menu: whether this build
    /// can use the App Group (widgets and push share it) and which keychains hold
    /// the token. Turns "why was I signed out" into something checkable.
    public static func diagnostics() -> String {
        let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil
        let found = queries.map { base -> Bool in
            var q = base
            q[kSecReturnData as String] = false
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            return SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess
        }
        let shared = found.first == true && queries.count > 1
        return "App Group \(group ? "on" : "off") · token \(shared ? "shared" : (found.contains(true) ? "app only" : "missing"))"
    }

    public static func client() -> APIClient? {
        load()?.client()
    }

    // MARK: Keychain

    /// The App Group keychain first (shared with the widgets), then the app's own
    /// keychain. Feather can sign with a profile that lacks the App Group; then
    /// the group write fails with errSecMissingEntitlement and only the app's own
    /// keychain keeps the token.
    private static var queries: [[String: Any]] {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        #if os(iOS)
        var shared = base
        shared[kSecAttrAccessGroup as String] = appGroup
        return [shared, base]
        #else
        return [base]
        #endif
    }

    private static func readToken() -> String? {
        for base in queries {
            var q = base
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: CFTypeRef?
            if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
               let data = out as? Data, let token = String(data: data, encoding: .utf8) {
                return token
            }
        }
        return nil
    }

    private static func writeToken(_ token: String) {
        // A query without an access group matches every group, so clear first,
        // then add one copy per keychain.
        for base in queries { SecItemDelete(base as CFDictionary) }
        for base in queries {
            var q = base
            q[kSecValueData as String] = Data(token.utf8)
            // Widgets refresh while the phone is locked.
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(q as CFDictionary, nil)
        }
    }
}
