import Foundation
import Security

/// Small blobs the app and its widget extension both read and write, kept in
/// the keychain groups the sign-in record uses (the App Group, then the team
/// group). On a build signed without the App Group, UserDefaults are per
/// process, so this is the only place the widget's page and its run journal
/// can be seen by both sides: whichever process runs a widget button's intent,
/// and the app's Widget diagnostics.
public enum SharedKeychain {
    private static let service = "org.elabx.fusionha.shared-state"

    private static func query(_ account: String, group: String?) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    /// The groups to try, in order. With no team group found, the process's
    /// own default group (no access group named) still keeps its own copy.
    private static var groups: [String?] {
        var out: [String?] = []
        #if os(iOS)
        out.append(CredentialStore.appGroup)
        #endif
        out += CredentialStore.teamGroups.map { Optional($0) }
        if CredentialStore.teamGroups.isEmpty { out.append(nil) }
        return out
    }

    /// The first copy found, or nil.
    public static func read(_ account: String) -> Data? {
        for group in groups {
            var q = query(account, group: group)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: CFTypeRef?
            if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data {
                return data
            }
        }
        return nil
    }

    /// Writes every group this signature may use (a missing entitlement just
    /// fails that group), so the copy read first is always the newest.
    @discardableResult
    public static func write(_ data: Data, _ account: String) -> OSStatus {
        var last = errSecParam
        for group in groups {
            let base = query(account, group: group)
            let update: [String: Any] = [kSecValueData as String: data]
            var status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
            if status == errSecItemNotFound {
                var add = base
                add[kSecValueData as String] = data
                add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
                status = SecItemAdd(add as CFDictionary, nil)
            }
            if status == errSecSuccess || last != errSecSuccess { last = status }
        }
        return last
    }

    public static func delete(_ account: String) {
        for group in groups { SecItemDelete(query(account, group: group) as CFDictionary) }
    }
}
