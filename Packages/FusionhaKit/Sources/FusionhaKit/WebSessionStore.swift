import Foundation
import Security

/// The web app's `fusionha_session` cookie value, captured at sign-in so the
/// in-app web panels (Settings → Naming, Custom Formats …) open signed in.
/// Kept in the app's own Keychain next to the API token; the widgets never need it.
public enum WebSessionStore {
    private static let service = "org.elabx.fusionha.web-session"

    public struct Session: Sendable, Equatable {
        public let serverURL: URL
        public let token: String
    }

    /// Stores the cookie for this server. A nil token (e.g. the cookie was not
    /// set) clears any older one, so a stale session never leaks across servers.
    public static func save(_ token: String?, server: URL) {
        clear()
        guard let token, !token.isEmpty else { return }
        var q = base
        q[kSecAttrAccount as String] = server.absoluteString
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    public static func load() -> Session? {
        var q = base
        q[kSecReturnData as String] = true
        q[kSecReturnAttributes as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let item = out as? [String: Any],
              let data = item[kSecValueData as String] as? Data,
              let token = String(data: data, encoding: .utf8),
              let account = item[kSecAttrAccount as String] as? String,
              let url = URL(string: account) else { return nil }
        return Session(serverURL: url, token: token)
    }

    public static func clear() {
        SecItemDelete(base as CFDictionary)
    }

    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
    }
}
