import Foundation

// Settings › Media Management › Import Library (web `ImportLauncher`,
// `ImportWorkspaceModal`, `lib/api/import.ts`; backend `import_routes.py`).
// The resumable triage session: one child scan per root, server-side
// decisions keyed by `(scan_id, folder_key)`, a backgrounded commit that is
// polled, and the post-import analysis task with its pause/resume/cancel.

// MARK: Models

/// The post-import MediaInfo analysis scoped to one import job (`SessionEnrichmentRead`).
public struct LibraryImportEnrichment: Decodable, Sendable, Hashable {
    /// `active` · `paused` · `cancelled`
    public let control: String?
    /// `analyzing` · `complete` · `paused` · `cancelled`
    public let state: String?
    public let total: Int?
    public let enriched: Int?
    public let pending: Int?
    public let issue: Int?
    public let issues: [EnrichmentIssue]?
}

/// A launcher row: a draft to resume or a recent import (`ImportSessionSummaryRead`).
public struct LibraryImportSummary: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    /// `draft` · `committing` · `committed` · `failed` · `discarded`
    public let status: String
    public let createdAt: String?
    public let updatedAt: String?
    /// The child scan count.
    public let sources: Int?
    public let roots: [String]?
    public let matched: Int?
    public let needsYou: Int?
    public let ready: Int?
    public let files: Int?
    public let titles: Int?
    public let enrichment: LibraryImportEnrichment?
}

/// One child scan: a Sources card (`ImportSessionSourceRead`).
public struct LibraryImportSource: Decodable, Sendable, Hashable, Identifiable {
    public let scanId: Int
    public let rootFolderId: Int?
    public let path: String?
    public let tier: String?
    public let kind: String?
    /// `scanning` · `ready` · `failed` · `interrupted`
    public let status: String
    public let items: Int?
    public let files: Int?
    public let error: String?
    public let scanTotal: Int?
    public let scanDone: Int?
    /// `match` · `filescan` · `done`
    public let scanPhase: String?
    public let stalled: Bool?

    public var id: Int { scanId }
    public var qualityTier: QualityTier? { tier.flatMap(QualityTier.init(rawValue:)) }
}

/// One version line under a proposed title (`ImportScanVersionRead`).
public struct LibraryImportVersion: Decodable, Sendable, Hashable {
    public let tier: QualityTier
    public let rootFolderId: Int
    public let folder: String
    /// The detected cut, nil for the plain edition.
    public let edition: String?
    public let alreadyImported: Bool?
}

/// One triage row with its decisions applied (`ImportSessionItemRead`).
public struct LibraryImportItem: Decodable, Sendable, Hashable, Identifiable {
    public let groupId: Int
    public let tmdbId: Int?
    public let title: String
    public let year: Int?
    public let kind: MediaKind
    public let confidence: String
    /// `id` (exact, from an embedded id) or `title`.
    public let matchedBy: String?
    public var monitored: Bool
    public let versions: [LibraryImportVersion]?
    public let alreadyImported: Bool?
    public let scanId: Int
    public let folderKey: String
    public var accepted: Bool
    public var qualityProfileId: Int?
    public let overrideTmdbId: Int?
    /// The user's cut override; nil uses the detected edition.
    public var variant: String?
    public var isNew: Bool?
    public var changedSinceReviewed: Bool?
    public let isAnime: Bool?

    /// The PATCH key: `scan_id:folder_key` (never the positional `group_id`).
    public var id: String { "\(scanId):\(folderKey)" }
    public var matched: Bool { tmdbId != nil }
}

/// The commit preview across every source (`ImportSessionPreviewRead`).
public struct LibraryImportPreview: Decodable, Sendable, Hashable {
    public let titles: Int?
    public let files: Int?
    /// Files per tier, keyed `HD-1080p` / `UHD-2160p`.
    public let perTier: [String: Int]?
}

public struct LibraryImportCommittedVersion: Decodable, Sendable, Hashable {
    public let tier: QualityTier
    public let created: Bool?
    public let filesCreated: Int?
    public let filesSkipped: Int?
}

public struct LibraryImportCommittedItem: Decodable, Sendable, Hashable {
    public let itemId: Int
    public let tmdbId: Int
    public let created: Bool
    public let versions: [LibraryImportCommittedVersion]?
}

/// The stored `commit_result`: the report once committed, or `{error}` when the runner failed.
public struct LibraryImportCommitResult: Decodable, Sendable, Hashable {
    public let items: [LibraryImportCommittedItem]?
    public let error: String?
}

/// The whole triage payload (`ImportSessionRead`).
public struct LibraryImportSession: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let status: String
    public let createdAt: String?
    public let updatedAt: String?
    public let sources: [LibraryImportSource]?
    public var items: [LibraryImportItem]?
    public let preview: LibraryImportPreview?
    public let commitResult: LibraryImportCommitResult?
    public let commitTotal: Int?
    public let commitDone: Int?
    public let commitPhase: String?
    public let commitStalled: Bool?
    public let enrichment: LibraryImportEnrichment?

    public var isDraft: Bool { status == "draft" }
    public var isCommitting: Bool { status == "committing" }
    public var isCommitted: Bool { status == "committed" }
    public var isFailed: Bool { status == "failed" }
}

/// One root to scan, with the tier and kind to scan it as.
public struct LibraryImportRootPick: Sendable, Hashable {
    public let rootFolderId: Int
    public let tier: QualityTier
    public let kind: MediaKind

    public init(rootFolderId: Int, tier: QualityTier, kind: MediaKind) {
        self.rootFolderId = rootFolderId
        self.tier = tier
        self.kind = kind
    }
}

/// One decision upsert. Nil fields are left out of the body (left untouched).
public struct LibraryImportPatch: Sendable, Hashable {
    public let scanId: Int
    public let folderKey: String
    public var accepted: Bool?
    public var monitored: Bool?
    public var qualityProfileId: Int?
    public var variant: String?

    public init(scanId: Int, folderKey: String, accepted: Bool? = nil, monitored: Bool? = nil,
                qualityProfileId: Int? = nil, variant: String? = nil) {
        self.scanId = scanId
        self.folderKey = folderKey
        self.accepted = accepted
        self.monitored = monitored
        self.qualityProfileId = qualityProfileId
        self.variant = variant
    }

    public var key: String { "\(scanId):\(folderKey)" }

    /// This patch with `other`'s set fields laid over it (the debounce coalesce).
    public func merged(with other: LibraryImportPatch) -> LibraryImportPatch {
        var next = self
        if let v = other.accepted { next.accepted = v }
        if let v = other.monitored { next.monitored = v }
        if let v = other.qualityProfileId { next.qualityProfileId = v }
        if let v = other.variant { next.variant = v }
        return next
    }

    public var body: SettingsJSON {
        var fields: [String: SettingsJSON] = ["scan_id": .int(scanId), "folder_key": .string(folderKey)]
        if let accepted { fields["accepted"] = .bool(accepted) }
        if let monitored { fields["monitored"] = .bool(monitored) }
        if let qualityProfileId { fields["quality_profile_id"] = .int(qualityProfileId) }
        if let variant { fields["variant"] = .string(variant) }
        return .object(fields)
    }
}

/// The post-import analysis controls (`POST …/enrichment/{action}`).
public enum LibraryImportEnrichmentAction: String, Sendable {
    case pause, resume, cancel, dismiss
}

// MARK: Endpoints

extension APIClient {
    /// `GET /import/sessions?status=&limit=`, newest first.
    public func libraryImportSessions(status: String?, limit: Int? = nil) async throws -> [LibraryImportSummary] {
        var query: [URLQueryItem] = []
        if let status { query.append(URLQueryItem(name: "status", value: status)) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await get("/api/v1/import/sessions", query: query)
    }

    public func libraryImportSession(id: Int) async throws -> LibraryImportSession {
        try await get("/api/v1/import/session/\(id)")
    }

    /// `POST /import/session`: opens a draft and kicks one scan per root.
    public func startLibraryImport(_ roots: [LibraryImportRootPick]) async throws -> LibraryImportSession {
        let list: [SettingsJSON] = roots.map {
            ["root_folder_id": .int($0.rootFolderId), "tier": .string($0.tier.rawValue), "kind": .string($0.kind.rawValue)]
        }
        return try await sendJSON("POST", "/api/v1/import/session", ["roots": .array(list)])
    }

    /// `PATCH /import/session/{id}/decisions`: a batch of decision upserts.
    public func patchLibraryImport(id: Int, patches: [LibraryImportPatch]) async throws -> LibraryImportSession {
        try await sendJSON("PATCH", "/api/v1/import/session/\(id)/decisions", ["patches": .array(patches.map(\.body))])
    }

    /// `POST /import/session/{id}/rescan`: one source, or every source when `scanId` is nil.
    public func rescanLibraryImport(id: Int, scanId: Int? = nil) async throws -> LibraryImportSession {
        var fields: [String: SettingsJSON] = [:]
        if let scanId { fields["scan_id"] = .int(scanId) }
        let body = SettingsJSON.object(fields)
        return try await sendJSON("POST", "/api/v1/import/session/\(id)/rescan", body)
    }

    /// `POST /import/session/{id}/discard`: files on disk are untouched.
    public func discardLibraryImport(id: Int) async throws -> LibraryImportSession {
        try await sendJSON("POST", "/api/v1/import/session/\(id)/discard")
    }

    /// `POST /import/session/{id}/commit`: returns 202 with the session `committing`; poll it.
    public func commitLibraryImport(id: Int) async throws -> LibraryImportSession {
        try await sendJSON("POST", "/api/v1/import/session/\(id)/commit")
    }

    /// `POST /import/scan/{scanId}/override`: repoints one folder group at a TMDB id.
    public func overrideLibraryImportMatch(scanId: Int, groupId: Int, tmdbId: Int) async throws {
        try await sendJSON("POST", "/api/v1/import/scan/\(scanId)/override",
                           ["group_id": .int(groupId), "tmdb_id": .int(tmdbId)])
    }

    public func libraryImportEnrichment(id: Int, _ action: LibraryImportEnrichmentAction) async throws {
        try await sendJSON("POST", "/api/v1/import/session/\(id)/enrichment/\(action.rawValue)")
    }
}
