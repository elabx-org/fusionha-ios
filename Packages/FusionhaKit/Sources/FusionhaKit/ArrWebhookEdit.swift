import Foundation

// Settings › Connect › "Registered by external tools": the native add/edit
// sheet's pure logic (web `ArrWebhookEditDialog.tsx`, `secret-placeholder.ts`).

/// One `from → to` path prefix rewrite on an arr webhook.
public struct ArrWebhookPathMapping: Codable, Sendable, Hashable, Identifiable {
    /// Local row identity for the editor; never on the wire.
    public let id: UUID
    public var from: String
    public var to: String

    public init(from: String, to: String) {
        self.id = UUID()
        self.from = from
        self.to = to
    }

    private enum CodingKeys: String, CodingKey { case from, to }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(from: try c.decode(String.self, forKey: .from), to: try c.decode(String.self, forKey: .to))
    }
}

/// The four trigger groups of the "Trigger on" chip grid, in order.
public enum ArrWebhookTriggerGroup: String, CaseIterable, Sendable {
    case library, removals, problems, system

    public var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// The 14 `ArrWebhookWrite` trigger flags, keyed by their wire names.
public enum ArrWebhookTrigger: String, CaseIterable, Sendable, Identifiable {
    case onGrab = "on_grab"
    case onMediaAdded = "on_media_added"
    case onImport = "on_import"
    case onUpgrade = "on_upgrade"
    case onRename = "on_rename"
    case onMediaRemoved = "on_media_removed"
    case onDelete = "on_delete"
    case onDeleteForUpgrade = "on_delete_for_upgrade"
    case onManualInteractionRequired = "on_manual_interaction_required"
    case onImportFailure = "on_import_failure"
    case onDownloadFailure = "on_download_failure"
    case onHealthIssue = "on_health_issue"
    case onHealthRestored = "on_health_restored"
    case onApplicationUpdate = "on_application_update"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .onGrab: return "Grab"
        case .onMediaAdded: return "Media added"
        case .onImport: return "Import"
        case .onUpgrade: return "Upgrade"
        case .onRename: return "Rename"
        case .onMediaRemoved: return "Media removed"
        case .onDelete: return "File deleted"
        case .onDeleteForUpgrade: return "Deleted for upgrade"
        case .onManualInteractionRequired: return "Needs manual action"
        case .onImportFailure: return "Import failed"
        case .onDownloadFailure: return "Download failed"
        case .onHealthIssue: return "Health issue"
        case .onHealthRestored: return "Health restored"
        case .onApplicationUpdate: return "App update"
        }
    }

    public var group: ArrWebhookTriggerGroup {
        switch self {
        case .onGrab, .onMediaAdded, .onImport, .onUpgrade, .onRename: return .library
        case .onMediaRemoved, .onDelete, .onDeleteForUpgrade: return .removals
        case .onManualInteractionRequired, .onImportFailure, .onDownloadFailure: return .problems
        case .onHealthIssue, .onHealthRestored, .onApplicationUpdate: return .system
        }
    }

    /// The server's defaults for a new row: Import and Upgrade on.
    public var defaultOn: Bool { self == .onImport || self == .onUpgrade }

    public static func inGroup(_ group: ArrWebhookTriggerGroup) -> [ArrWebhookTrigger] {
        allCases.filter { $0.group == group }
    }

    /// The flag as read off a saved row (nil when the server didn't send it).
    public func value(in webhook: ArrWebhookGroup.Webhook) -> Bool? {
        switch self {
        case .onGrab: return webhook.onGrab
        case .onMediaAdded: return webhook.onMediaAdded
        case .onImport: return webhook.onImport
        case .onUpgrade: return webhook.onUpgrade
        case .onRename: return webhook.onRename
        case .onMediaRemoved: return webhook.onMediaRemoved
        case .onDelete: return webhook.onDelete
        case .onDeleteForUpgrade: return webhook.onDeleteForUpgrade
        case .onManualInteractionRequired: return webhook.onManualInteractionRequired
        case .onImportFailure: return webhook.onImportFailure
        case .onDownloadFailure: return webhook.onDownloadFailure
        case .onHealthIssue: return webhook.onHealthIssue
        case .onHealthRestored: return webhook.onHealthRestored
        case .onApplicationUpdate: return webhook.onApplicationUpdate
        }
    }
}

/// The secret placeholder contract (backend `secret_placeholder.py`): reads
/// mask every header value; sending the mask back keeps the stored value.
public enum SecretPlaceholder {
    public static let value = "••••••"
}

/// One editable header row. `stored`: the read masked its value, so an empty
/// input means "keep what's saved".
public struct SecretHeaderRow: Sendable, Hashable, Identifiable {
    public let id: UUID
    public var key: String
    public var value: String
    public var stored: Bool
    public var originalKey: String?

    public init(key: String = "", value: String = "", stored: Bool = false, originalKey: String? = nil) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.stored = stored
        self.originalKey = originalKey
    }

    /// Rows for a masked `headers` read, sorted by key.
    public static func rows(from headers: [String: String]?) -> [SecretHeaderRow] {
        (headers ?? [:]).sorted { $0.key < $1.key }.map { key, value in
            value == SecretPlaceholder.value
                ? SecretHeaderRow(key: key, stored: true, originalKey: key)
                : SecretHeaderRow(key: key, value: value)
        }
    }

    /// The `headers` to write: an untouched stored row sends the placeholder;
    /// a renamed one with no new value is dropped; blank keys are skipped.
    public static func headersForWrite(_ rows: [SecretHeaderRow]) -> [String: String] {
        var out: [String: String] = [:]
        for row in rows {
            let key = row.key.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            if row.stored && row.value.isEmpty {
                if key == row.originalKey { out[key] = SecretPlaceholder.value }
                continue
            }
            out[key] = row.value
        }
        return out
    }
}

/// The add/edit form's state and its write body.
public struct ArrWebhookDraft: Sendable, Equatable {
    public var name: String
    public var url: String
    public var method: Int
    public var username: String
    /// Blank keeps the stored secret (sent as `null`).
    public var password: String
    public var headers: [SecretHeaderRow]
    public var sendValidationResults: Bool
    public var instanceId: Int?
    public var triggers: [ArrWebhookTrigger: Bool]
    public var pathMappings: [ArrWebhookPathMapping]
    public let isNew: Bool
    public let passwordConfigured: Bool

    public init(webhook: ArrWebhookGroup.Webhook?, instanceId: Int? = nil) {
        isNew = webhook == nil
        name = webhook?.name ?? ""
        url = webhook?.url ?? ""
        method = webhook?.method ?? 1
        username = webhook?.username ?? ""
        password = ""
        headers = SecretHeaderRow.rows(from: webhook?.headers)
        sendValidationResults = webhook?.sendValidationResults ?? true
        self.instanceId = webhook?.instanceId ?? instanceId
        var flags: [ArrWebhookTrigger: Bool] = [:]
        for trigger in ArrWebhookTrigger.allCases {
            flags[trigger] = webhook.flatMap { trigger.value(in: $0) } ?? trigger.defaultOn
        }
        triggers = flags
        pathMappings = webhook?.pathMappings ?? []
        passwordConfigured = webhook?.passwordConfigured ?? false
    }

    /// Auth & headers starts open when anything is set there.
    public var authStartsOpen: Bool {
        !username.isEmpty || passwordConfigured || !headers.isEmpty
    }

    /// Name and URL are required; a new row also needs its virtual instance.
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !url.trimmingCharacters(in: .whitespaces).isEmpty
            && (!isNew || instanceId != nil)
    }

    public func isOn(_ trigger: ArrWebhookTrigger) -> Bool { triggers[trigger] ?? trigger.defaultOn }

    /// `ArrWebhookUpdate` (plus `instance_id` for a create).
    public var body: SettingsJSON {
        let trimmedUser = username.trimmingCharacters(in: .whitespaces)
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)
        var fields: [String: SettingsJSON] = [
            "name": .string(name.trimmingCharacters(in: .whitespaces)),
            "url": .string(url.trimmingCharacters(in: .whitespaces)),
            "method": .int(method),
            "username": trimmedUser.isEmpty ? .null : .string(trimmedUser),
            "headers": .object(SecretHeaderRow.headersForWrite(headers).mapValues { .string($0) }),
            "send_validation_results": .bool(sendValidationResults),
            "password": trimmedPassword.isEmpty ? .null : .string(trimmedPassword),
            "path_mappings": .array(pathMappings.compactMap { mapping in
                let from = mapping.from.trimmingCharacters(in: .whitespaces)
                let to = mapping.to.trimmingCharacters(in: .whitespaces)
                guard !from.isEmpty, !to.isEmpty else { return nil }
                return .object(["from": .string(from), "to": .string(to)])
            }),
        ]
        for trigger in ArrWebhookTrigger.allCases { fields[trigger.rawValue] = .bool(isOn(trigger)) }
        if isNew, let instanceId { fields["instance_id"] = .int(instanceId) }
        return .object(fields)
    }
}
