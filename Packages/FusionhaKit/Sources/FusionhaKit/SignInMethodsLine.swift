import Foundation

/// v2 Account's Sign-in methods subtitle (mock requests.js `acctGroups`):
/// "Password · Plex (eafx)", the active methods, primary first.
public enum SignInMethodsLine {
    public static func text(_ credentials: [UserCredential]?, plexUsername: String? = nil) -> String? {
        let active = (credentials ?? []).filter(\.isActive).sorted { $0.isPrimary && !$1.isPrimary }
        var parts: [String] = []
        for c in active {
            let word: String
            switch c.provider {
            case "local": word = "Password"
            case "plex": word = (c.displayHandle ?? plexUsername).map { "Plex (\($0))" } ?? "Plex"
            case "oidc": word = "Single sign-on"
            default: word = c.provider.capitalized
            }
            if !parts.contains(word) { parts.append(word) }
        }
        if parts.isEmpty, let plexUsername { parts.append("Plex (\(plexUsername))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
