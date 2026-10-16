import Foundation

// Every sentence Settings › Security shows for a status, derived from the
// `GET /system/secrets/status` fields only (web `security-format.ts`,
// `security-scope.ts`).

public enum SecretsTone: Sendable {
    case ok, busy, locked, neutral
}

public enum SecretsHeroIcon: Sendable {
    case shield, lock, rotate
}

public struct SecretsHero: Sendable, Hashable {
    public let title: String
    public let sub: String
    public let icon: SecretsHeroIcon
}

public struct SecretsProgressInfo: Sendable, Hashable {
    public let label: String
    public let done: Int
    public let total: Int
    /// 0–1, clamped.
    public let fraction: Double
}

public struct SecretsLockedRow: Sendable, Hashable {
    public let label: String
    public let small: String?
}

extension SecretsStatus {
    public var isLocked: Bool { state.hasPrefix("locked_") }
    public var isRotating: Bool { state == "rotating" || rotation?.running == true }
    /// A rotation that stopped before it finished (resumable).
    public var rotationStalled: Bool { state == "rotating" && rotation?.running != true }
    public var isEncrypting: Bool { encryptPass.running }
    public var isBusy: Bool { encryptPass.running || rotation?.running == true }

    public var tone: SecretsTone {
        if isLocked { return .locked }
        if isRotating || isEncrypting { return .busy }
        if plaintextRemaining > 0 { return .neutral }
        return .ok
    }

    public var progress: SecretsProgressInfo? {
        if let r = rotation, r.running { return Self.progress("Re-encrypting with the new key", r.done, r.total) }
        if encryptPass.running {
            return Self.progress("Encrypting existing secrets", encryptPass.done, encryptPass.total)
        }
        return nil
    }

    private static func progress(_ label: String, _ done: Int, _ total: Int) -> SecretsProgressInfo {
        let f = total > 0 ? min(1, max(0, Double(done) / Double(total))) : 0
        return SecretsProgressInfo(label: label, done: done, total: total, fraction: f)
    }

    public var hero: SecretsHero {
        if rotationStalled {
            return SecretsHero(title: "The key rotation stopped before it finished",
                               sub: "Nothing was lost. Secrets are readable with either key until the rotation finishes. Resume it to re-encrypt the rest.",
                               icon: .rotate)
        }
        if isRotating {
            return SecretsHero(title: "Rotating the key",
                               sub: "Downloads, indexers and notifications keep running. Key actions are paused until this finishes. If fusionha restarts, the rotation picks up where it stopped.",
                               icon: .rotate)
        }
        if isEncrypting {
            return SecretsHero(title: "Encrypting existing secrets",
                               sub: "Everything keeps working while this runs. Secrets not yet encrypted stay readable, and saving a setting encrypts it straight away.",
                               icon: .lock)
        }
        if !unreadable.isEmpty {
            let total = encryptedCount + unreadable.count
            return SecretsHero(title: "Encrypted with a new key · \(encryptedCount) of \(SecretsCopy.secrets(total)) readable",
                               sub: "You started over with a new key. Secrets the old key encrypted can’t be read. Reset them below, then enter fresh values where they’re used.",
                               icon: .shield)
        }
        if plaintextRemaining > 0 {
            return SecretsHero(title: "\(encryptedCount) of \(SecretsCopy.secrets(encryptedCount + plaintextRemaining)) encrypted",
                               sub: "The rest are encrypted the next time fusionha starts, and saving a setting encrypts it straight away.",
                               icon: .lock)
        }
        if encryptedCount == 0 {
            return SecretsHero(title: "No secrets stored yet",
                               sub: "Every password, API key and token you save is encrypted as it is saved.", icon: .shield)
        }
        let title = encryptedCount == 1 ? "Your 1 secret is encrypted at rest" : "All \(encryptedCount) secrets are encrypted at rest"
        return SecretsHero(title: title, sub: SecretsCopy.scopeSentence(integrations), icon: .shield)
    }

    public var sourceLabel: String {
        switch keySource {
        case "env": return "Environment · FUSIONHA_SECRET_KEY"
        case "file": return "Key file"
        default: return "No key found"
        }
    }

    /// Why Rotate is disabled, or nil when it is allowed.
    public var rotateBlockedReason: String? {
        if keySource == "env" { return "The key comes from FUSIONHA_SECRET_KEY" }
        if isRotating { return SecretsCopy.rotatingReason }
        if isEncrypting { return "Wait for encryption to finish." }
        return nil
    }

    /// Why Download recovery key is disabled, or nil.
    public var recoveryBlockedReason: String? { isRotating ? SecretsCopy.rotatingReason : nil }
}

public enum SecretsCopy {
    public static let rotatingReason = "A key rotation is running. Wait for it to finish."
    /// The exact phrase the server checks for Start over.
    public static let startOverPhrase = "START OVER"
    public static let passwordHint = "Needs your password, and an admin account and password at least 24 hours old."
    public static let plexHint = "Opens Plex to confirm it’s you. Needs an admin account and Plex link at least 24 hours old."
    public static let plexTimeout = "Plex wasn’t approved within 15 minutes, so that request expired. Try again."

    public static func secrets(_ n: Int) -> String { "\(n) \(n == 1 ? "secret" : "secrets")" }

    static func count(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }

    /// "a, b and c".
    static func joinAnd(_ parts: [String]) -> String {
        guard parts.count > 1 else { return parts.joined() }
        return parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
    }

    /// Up to `max` names, then "+N more". Repeated names show once.
    public static func nameList(_ names: [String], max: Int = 3) -> String {
        var unique: [String] = []
        for n in names where !unique.contains(n) { unique.append(n) }
        if unique.count <= max { return unique.joined(separator: ", ") }
        return unique.prefix(max).joined(separator: ", ") + " +\(unique.count - max) more"
    }

    /// The OK hero's sub line, with live counts.
    public static func scopeSentence(_ i: SecretsIntegrations?) -> String {
        var parts: [String] = []
        if let i {
            let rows: [(Int, String, String)] = [
                (i.indexers.count, "indexer", "indexers"),
                (i.downloadClients.count, "download client", "download clients"),
                (i.virtualInstances.count, "virtual instance", "virtual instances"),
                (i.notificationAgents.count, "notification agent", "notification agents"),
                (i.connectWebhooks.count, "Connect webhook", "Connect webhooks"),
                (i.arrConnections.count, "arr connection", "arr connections"),
            ]
            parts = rows.filter { $0.0 > 0 }.map { count($0.0, $0.1, $0.2) }
        }
        if parts.isEmpty { return "Passwords, API keys and tokens in app settings such as the TMDB key." }
        return "Passwords, API keys and tokens for \(joinAnd(parts)), plus app settings such as the TMDB key."
    }

    /// The locked card's two columns, naming the real integrations.
    public static func lockedLists(_ i: SecretsIntegrations?) -> (works: [SecretsLockedRow], paused: [SecretsLockedRow]) {
        let i = i ?? SecretsIntegrations()
        let notify = [
            i.notificationAgents.isEmpty ? "" : nameList(i.notificationAgents, max: 2),
            i.connectWebhooks.isEmpty ? "" : count(i.connectWebhooks.count, "Connect webhook", "Connect webhooks"),
        ].filter { !$0.isEmpty }
        let works = [
            SecretsLockedRow(label: "Sign-in and the app", small: nil),
            SecretsLockedRow(label: "Overseerr requests", small: i.virtualInstances.isEmpty ? nil : nameList(i.virtualInstances, max: 6)),
            SecretsLockedRow(label: "Prowlarr sync", small: nil),
            SecretsLockedRow(label: "Your library and files", small: nil),
        ]
        let paused = [
            SecretsLockedRow(label: "Downloads", small: i.downloadClients.isEmpty ? nil : nameList(i.downloadClients)),
            SecretsLockedRow(label: "Indexers", small: i.indexers.isEmpty ? nil : count(i.indexers.count, "indexer", "indexers")),
            SecretsLockedRow(label: "Plex sign-in", small: nil),
            SecretsLockedRow(label: "Notifications", small: notify.isEmpty ? nil : notify.joined(separator: ", ")),
        ]
        return (works, paused)
    }

    /// `3f9a1c0be27d5a46` → `3f9a·1c0b·e27d·5a46`.
    public static func groupFingerprint(_ fp: String?) -> String {
        guard let fp, !fp.isEmpty else { return "—" }
        var groups: [String] = []
        var rest = Substring(fp)
        while !rest.isEmpty {
            groups.append(String(rest.prefix(4)))
            rest = rest.dropFirst(4)
        }
        return groups.joined(separator: "·")
    }

    /// A server timestamp as a local medium date + short time. Naive stamps are UTC.
    public static func stamp(_ iso: String?, timeZone: TimeZone = .current) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        guard let date = ServerTime.parse(iso) else { return iso }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.timeZone = timeZone
        return f.string(from: date)
    }

    static let kindLabels: [String: String] = [
        "setting": "App setting", "download_client": "Download client", "search_indexer": "Indexer",
        "virtual_instance": "Virtual instance", "notification_agent": "Notification agent",
        "arr_connection": "arr connection", "arr_indexer": "Prowlarr indexer", "arr_webhook": "Connect webhook",
    ]

    public static func kindLabel(_ kind: String) -> String { kindLabels[kind] ?? "Secret" }

    /// Settings the server mints itself: a reset makes a new one instead of clearing.
    static let regenerated: [String: String] = [
        "setting:app_api_key": "New fusionha API key. Anything using the old one must be updated.",
        "setting:demo_access_token": "New demo access token. Demo links already shared stop working.",
        "setting:webpush_vapid_private": "Web Push signing key: devices must re-subscribe.",
        "setting:plex_pin_secret": "Plex sign-in binding secret: a new one is made, and a Plex sign-in in progress has to start again.",
    ]

    public static func resetRegenerates(_ item: SecretsUnreadable) -> Bool {
        item.kind == "virtual_instance" || regenerated[item.name] != nil
    }

    /// What a reset does to this one secret.
    public static func resetConsequence(_ item: SecretsUnreadable) -> String {
        if item.kind == "virtual_instance" { return "New instance API key. Re-pair Overseerr and Prowlarr afterwards." }
        return regenerated[item.name] ?? "Cleared. Enter a new value where it’s used."
    }

    public static func resetLabel(_ item: SecretsUnreadable) -> String {
        if item.kind == "virtual_instance" { return "Reset: make a new instance key. Re-pair Overseerr and Prowlarr afterwards." }
        return resetRegenerates(item) ? "Reset: make a new value" : "Reset: clear this value so you can enter a new one"
    }
}
