import Foundation

// The reviewed metadata-source switch (MetadataSwitchDialog.tsx): preview the
// target's match, review the numbering plan and the file renames, commit with
// the plan's hash, poll the run, and offer Undo.

public struct MetadataSwitchMatch: Decodable, Sendable, Hashable {
    public let id: Int
    public let title: String?
    public let year: Int?
    public let poster: String?
}

public struct MetadataSwitchFile: Decodable, Sendable, Hashable, Identifiable {
    public let mediaFileId: Int
    public let rawName: String
    public let parsedKey: String?
    public let quality: String?
    public let matchedSeason: Int?
    public let matchedNumber: Int?
    public let matchedTitle: String?
    public let newName: String?
    /// `sxxexx` · `title` · `title-only-warn` (flagged) · `unmatched`.
    public let confidence: String
    public var id: Int { mediaFileId }
}

/// `POST /api/v1/library/{id}/metadata-switch/preview`.
public struct MetadataSwitchPreview: Decodable, Sendable {
    public let targetProvider: String
    public let currentProvider: String?
    public let needsSearch: Bool?
    public let matched: MetadataSwitchMatch?
    public let planHash: String?
    public let activeQueueBlocked: Bool?
    public let files: [MetadataSwitchFile]?
    public let renameCount: Int?
}

/// `GET /api/v1/library/{id}/numbering/plan`.
public struct NumberingPlan: Decodable, Sendable {
    public let target: String?
    public let owner: String?
    public let planHash: String
    public let counts: [String: Int]?
    public let blockedByQueue: Bool?
    public let blockedEpisodeIds: [Int]?
}

struct MetadataSwitchPreviewBody: Encodable {
    let targetProvider: String
    let targetId: Int?
}

public struct MetadataSwitchCommitBody: Encodable, Sendable {
    public let targetProvider: String
    public let targetId: Int?
    public let renameFiles: Bool
    public let excludeFileIds: [Int]
    public let planHash: String

    public init(targetProvider: String, targetId: Int?, renameFiles: Bool, excludeFileIds: [Int], planHash: String) {
        self.targetProvider = targetProvider
        self.targetId = targetId
        self.renameFiles = renameFiles
        self.excludeFileIds = excludeFileIds
        self.planHash = planHash
    }
}

public struct MetadataSwitchDispatch: Decodable, Sendable { public let runId: Int }

/// The run's `metadata_switch_summary` once terminal.
public struct MetadataSwitchSummary: Decodable, Sendable, Hashable {
    public let renamedFiles: Int?
    public let undoAvailable: Bool?
}

public struct MetadataSwitchUndo: Decodable, Sendable {
    public let restoredProvider: String?
    public let renamedBack: Int?
}

extension APIClient {
    public func metadataSwitchPreview(itemId: Int, target: String, targetId: Int? = nil) async throws -> MetadataSwitchPreview {
        try await send("POST", "/api/v1/library/\(itemId)/metadata-switch/preview",
                       body: MetadataSwitchPreviewBody(targetProvider: target, targetId: target == "hybrid" ? nil : targetId))
    }

    /// `intent`: `switch` (a metadata switch) or `override` (a numbering pin).
    public func numberingPlan(itemId: Int, target: String, intent: String, targetId: Int? = nil) async throws -> NumberingPlan {
        var query = [URLQueryItem(name: "target", value: target), URLQueryItem(name: "intent", value: intent)]
        if let targetId { query.append(URLQueryItem(name: "target_id", value: "\(targetId)")) }
        return try await get("/api/v1/library/\(itemId)/numbering/plan", query: query)
    }

    public func metadataSwitchCommit(itemId: Int, _ body: MetadataSwitchCommitBody) async throws -> MetadataSwitchDispatch {
        try await send("POST", "/api/v1/library/\(itemId)/metadata-switch/commit", body: body)
    }

    public func metadataSwitchUndo(itemId: Int) async throws -> MetadataSwitchUndo {
        try await send("POST", "/api/v1/library/\(itemId)/metadata-switch/undo", body: Optional<MetadataSwitchPreviewBody>.none)
    }

    /// The switch run's state and, once terminal, its summary.
    public func metadataSwitchRun(id: Int) async throws -> MetadataSwitchRun {
        try await get("/api/v1/system/runs/\(id)")
    }
}

public struct MetadataSwitchRun: Decodable, Sendable {
    public let status: String?
    public let metadataSwitchSummary: MetadataSwitchSummary?
    public var isRunning: Bool { status == "running" || status == "queued" }
}

/// Labels and counts the switch sheet and the Edit pickers share
/// (switch-providers.ts, plan-model.ts, numbering-diff.ts).
public enum MetadataSwitchLogic {
    public static let providers = ["tmdb", "tvdb", "hybrid"]

    /// The banner for a preview that failed: the server's words, a timeout in
    /// plain words, or the cause appended, so a report says what went wrong.
    public static func previewFailure(_ error: Error) -> String {
        if let api = error as? APIError { return api.serverMessage }
        if let url = error as? URLError, url.code == .timedOut {
            return "The server took too long to build the preview. Try again."
        }
        if case DecodingError.keyNotFound(let key, let context) = error {
            return "Couldn't preview the switch (missing \((context.codingPath + [key]).map(\.stringValue).joined(separator: ".")))."
        }
        if case DecodingError.typeMismatch(_, let context) = error {
            return "Couldn't preview the switch (unexpected \(context.codingPath.map(\.stringValue).joined(separator: ".")))."
        }
        if case DecodingError.valueNotFound(_, let context) = error {
            return "Couldn't preview the switch (empty \(context.codingPath.map(\.stringValue).joined(separator: ".")))."
        }
        return "Couldn't preview the switch: \(error.localizedDescription)"
    }

    public static func label(_ provider: String) -> String {
        switch provider {
        case "tvdb": return "TheTVDB"
        case "hybrid": return "Hybrid"
        case "tvmaze": return "TVmaze"
        default: return "TMDB"
        }
    }

    /// `currentProviderChoice`: the series' switch value (unknown reads as TMDB).
    public static func current(_ provider: String?) -> String {
        provider == "tvdb" || provider == "hybrid" ? provider! : "tmdb"
    }

    /// The plan's change count: every kind but `unchanged` (held = `keep_for_review`).
    public static func changeCount(_ plan: NumberingPlan) -> Int {
        let c = plan.counts ?? [:]
        return ["renumbered", "moved", "retitled", "added", "removed", "keep_for_review"].reduce(0) { $0 + (c[$1] ?? 0) }
    }

    /// "3 renumbered · 1 new · 12 unchanged".
    public static func summary(_ plan: NumberingPlan) -> String {
        let c = plan.counts ?? [:]
        let parts: [(String, String)] = [("renumbered", "renumbered"), ("moved", "moved"), ("retitled", "retitled"),
                                         ("added", "new"), ("removed", "removed"), ("keep_for_review", "held"),
                                         ("unchanged", "unchanged")]
        return parts.compactMap { key, word in (c[key] ?? 0) > 0 ? "\(c[key]!) \(word)" : nil }.joined(separator: " · ")
    }

    /// The footer's reason line (`planWhy`).
    public static func why(_ plan: NumberingPlan?, blocked: Bool) -> String {
        if blocked { return "Blocked: downloads in flight" }
        guard let plan else { return "" }
        let n = changeCount(plan)
        return "\(n) change\(n == 1 ? "" : "s") · nothing downloaded or deleted"
    }

    // MARK: Episode numbering pin (EditItemDialog #53)

    /// The provider's own numbering: TheTVDB for a tvdb/hybrid series, else TMDB.
    public static func numberingDefault(_ resolvedProvider: String?) -> String {
        resolvedProvider == "tvdb" || resolvedProvider == "hybrid" ? "tvdb" : "tmdb"
    }

    /// The honest selected value: a `tvmaze`/`tvdb` pin as-is, else the default.
    public static func numberingSource(pin: String?, resolvedProvider: String?) -> String {
        pin == "tvmaze" || pin == "tvdb" ? pin! : numberingDefault(resolvedProvider)
    }

    /// The picker's options as `(value, label)`.
    public static func numberingOptions(_ resolvedProvider: String?) -> [(String, String)] {
        numberingDefault(resolvedProvider) == "tvdb"
            ? [("tvdb", "Automatic · TheTVDB"), ("tvmaze", "TVmaze")]
            : [("tmdb", "Automatic · TMDB"), ("tvmaze", "TVmaze"), ("tvdb", "TheTVDB")]
    }
}
