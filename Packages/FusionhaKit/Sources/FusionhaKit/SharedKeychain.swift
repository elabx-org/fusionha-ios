import Foundation
import Security

/// Small blobs the app and its widget extension both read and write, kept in
/// the keychain groups the sign-in record uses (the App Group, then the team
/// group). On a build signed without the App Group, UserDefaults are per
/// process, so this is the only place the widget's page and its run journal
/// can be seen by both sides: whichever process runs a widget button's intent,
/// and the app's Widget diagnostics. When no keychain group takes a write (an
/// unsigned simulator build), it lands in this process's own defaults instead.
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

    private static func localKey(_ account: String) -> String { "sharedKeychain.\(account)" }

    /// The first keychain copy found, else this process's own fallback.
    public static func read(_ account: String) -> Data? {
        keychainRead(account) ?? UserDefaults.standard.data(forKey: localKey(account))
    }

    private static func keychainRead(_ account: String) -> Data? {
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
    /// Returns errSecSuccess when at least one group took it.
    @discardableResult
    public static func write(_ data: Data, _ account: String) -> OSStatus {
        var last = errSecParam
        for group in groups {
            let status = write(data, query(account, group: group))
            if status == errSecSuccess || last != errSecSuccess { last = status }
        }
        if last == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: localKey(account))
        } else {
            UserDefaults.standard.set(data, forKey: localKey(account))
        }
        return last
    }

    private static func write(_ data: Data, _ base: [String: Any]) -> OSStatus {
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return status }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil)
    }

    public static func delete(_ account: String) {
        for group in groups { SecItemDelete(query(account, group: group) as CFDictionary) }
        UserDefaults.standard.removeObject(forKey: localKey(account))
    }
}
