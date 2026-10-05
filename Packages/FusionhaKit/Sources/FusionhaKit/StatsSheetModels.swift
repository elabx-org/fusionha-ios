import Foundation

// The Library stats sheet's "In progress" + "Needs attention" sections
// (shell/OperationsPanel.tsx `OperationsList`, shell/AttentionControl.tsx
// `AttentionList`). Hand-written, tolerant of the 0.4.122 rename (`edition` /
// `movie_edition`) and of missing optional fields.

/// One `GET /api/v1/library/attention` row (`LibraryAttentionItem`).
public struct LibraryAttentionEntry: Decodable, Sendable, Hashable {
    public let itemId: Int
    public let title: String
    public let tier: QualityTier?
    public let edition: String?
    /// `dead_content` | `dead_link` | `not_found` | `partial` | `numbering_mismatch`
    /// | `metadata_removed` | `arr_scope_mismatch` (unknown kinds read as file rows).
    public let kind: String
    /// Server-built copy, shown verbatim.
    public let message: String

    private enum CodingKeys: String, CodingKey { case itemId, title, tier, edition, movieEdition, kind, message }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try c.decode(Int.self, forKey: .itemId)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        tier = try? c.decodeIfPresent(QualityTier.self, forKey: .tier)
        let cut = try c.decodeIfPresent(String.self, forKey: .edition)
        edition = try cut ?? c.decodeIfPresent(String.self, forKey: .movieEdition)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "not_found"
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
    }
}

/// One `GET /api/v1/system/runs/attention` row: a manual search that grabbed nothing.
public struct RunAttentionEntry: Decodable, Sendable, Hashable {
    public let runId: Int
    public let itemId: Int
    public let title: String?
    public let reason: String
}

/// One `GET /api/v1/system/indexers/unavailable` row: an indexer backed off after failures.
public struct UnavailableIndexer: Decodable, Sendable, Hashable, Identifiable {
    public let indexerId: Int
    public let name: String
    public let disabledTill: String?
    public let reason: String?
    public var id: Int { indexerId }

    /// `indexerRetryHint`: "retry in 12m" / "retry in 2h" / "retrying".
    public func retryHint(now: Date = Date()) -> String {
        guard let till = DetailText.instant(disabledTill) else { return "retrying" }
        let mins = Int((till.timeIntervalSince(now) / 60).rounded())
        if mins <= 0 { return "retrying" }
        if mins < 60 { return "retry in \(mins)m" }
        return "retry in \(Int((Double(mins) / 60).rounded()))h"
    }
}

/// `{items: [...]}` envelopes, tolerant of a missing list.
public struct ItemsEnvelope<Item: Decodable & Sendable>: Decodable, Sendable {
    public let items: [Item]

    private enum CodingKeys: String, CodingKey { case items }

    public init(items: [Item] = []) { self.items = items }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
    }
}

/// One `GET /api/v1/system/commands` entry with its timing (`CommandRead`).
public struct OperationCommand: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let status: String
    public let message: String?
    /// 0–1.
    public let progress: Double?
    public let started: String?
    public let ended: String?
}
