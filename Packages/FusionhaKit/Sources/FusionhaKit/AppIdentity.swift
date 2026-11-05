import Foundation

/// Which fusionha app this process belongs to: v1 (`org.elabx.fusionha`) or the
/// v2 product built beside it. Each target's Info.plist may name its App Group,
/// keychain namespace and URL scheme (`FusionhaAppGroup`, `FusionhaKeychainNamespace`,
/// `FusionhaURLScheme`); a missing key falls back to v1's value, so v1 and its
/// extensions behave exactly as before. Every App Group, keychain service, team
/// keychain group and `fusionha://` link derives from here, so v2 never reads,
/// writes or deletes v1's sign-in, and its links open v2.
public struct AppIdentity: Sendable, Equatable {
    public static let appGroupKey = "FusionhaAppGroup"
    public static let keychainNamespaceKey = "FusionhaKeychainNamespace"
    public static let urlSchemeKey = "FusionhaURLScheme"

    /// v1's values, as they were hard-coded before v2.
    public static let v1 = AppIdentity(appGroup: "group.org.elabx.fusionha",
                                       keychainNamespace: "org.elabx.fusionha",
                                       urlScheme: "fusionha")

    /// This process's identity, from its own bundle (the app's, or an extension's).
    public static let current = AppIdentity(info: Bundle.main.infoDictionary ?? [:])

    /// The App Group: shared defaults, the shared container and a keychain access group.
    public let appGroup: String
    /// The prefix of every keychain service and of the team keychain group.
    public let keychainNamespace: String
    /// The deep-link scheme, without `://`.
    public let urlScheme: String

    public init(appGroup: String, keychainNamespace: String, urlScheme: String) {
        self.appGroup = appGroup
        self.keychainNamespace = keychainNamespace
        self.urlScheme = urlScheme
    }

    /// Reads the three keys from an Info.plist dictionary; a missing or empty
    /// value keeps v1's.
    public init(info: [String: Any]) {
        func string(_ key: String, _ fallback: String) -> String {
            guard let value = info[key] as? String else { return fallback }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        }
        self.init(appGroup: string(Self.appGroupKey, Self.v1.appGroup),
                  keychainNamespace: string(Self.keychainNamespaceKey, Self.v1.keychainNamespace),
                  urlScheme: string(Self.urlSchemeKey, Self.v1.urlScheme))
    }

    /// v1 itself (its keychain namespace): only v1 keeps the legacy `TEAMID.*` group.
    public var isV1: Bool { keychainNamespace == Self.v1.keychainNamespace }

    /// A keychain service in this app's namespace: `api-token` → `org.elabx.fusionha.api-token`.
    public func service(_ name: String) -> String { "\(keychainNamespace).\(name)" }

    /// The explicit team keychain group's suffix (after `TEAMID.`).
    public var sharedKeychainSuffix: String { service("shared") }

    /// The team keychain groups to try for `prefix` (the 10-character team id),
    /// given this process's default access group. v1 keeps what it always tried:
    /// the explicit group, the literal `TEAMID.*` a re-signing tool may grant,
    /// and a wildcard default group. Any other identity gets only its own explicit
    /// group, never a wildcard, so it can't touch v1's items.
    public func teamGroups(prefix: String, defaultGroup: String) -> [String] {
        let explicit = "\(prefix).\(sharedKeychainSuffix)"
        guard isV1 else { return [explicit] }
        var groups = [explicit, "\(prefix).*"]
        if defaultGroup.hasSuffix("*"), !groups.contains(defaultGroup) { groups.append(defaultGroup) }
        return groups
    }

    /// `scheme://` + `rest`: `link("item/42")` → `fusionha://item/42`.
    public func link(_ rest: String) -> URL? { URL(string: "\(urlScheme)://\(rest)") }

    /// True when `url` is one of this app's deep links.
    public func owns(_ url: URL) -> Bool { url.scheme == urlScheme }
}
