import Foundation

// Wire models for the detail page's item actions (HeroActionRail): rename
// preview/apply, edition aliases and the episode-numbering fix. Same shapes as
// the server's `RenamePreviewRead`, `ItemEditionAliasRead` and `Numbering*Read`.

// MARK: Rename

/// One row of `GET /api/v1/library/{id}/rename?include_blocked=1`.
public struct RenamePreviewRow: Decodable, Sendable, Hashable, Identifiable {
    public let fileId: Int
    public let versionId: Int?
    public let from: String
    public let to: String
    public let blocked: Bool?
    /// `duplicate_name` · `destination_held` · `source_missing` · `destination_exists`.
    public let reason: String?
    public let blockedByFileId: Int?
    public let blockedByPath: String?

    public var id: Int { fileId }
    public var isBlocked: Bool { blocked == true }
}

/// `POST /api/v1/library/{id}/rename` body: `{}` for the whole title, else the scope facets.
public struct RenameApplyBody: Encodable, Sendable, Hashable {
    public let versionId: Int?
    public let season: Int?

    public init(versionId: Int? = nil, season: Int? = nil) {
        self.versionId = versionId
        self.season = season
    }
}

public struct RenameApplyResult: Decodable, Sendable, Hashable {
    public let applied: Int
    public let skipped: [RenamePreviewRow]?
}

// MARK: Edition aliases

/// One per-item edition alias (`ItemEditionAliasRead`).
public struct EditionAlias: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let term: String
    public let edition: String
    public let guarded: Bool?
}

/// `POST /api/v1/library/{id}/edition-aliases` body.
public struct EditionAliasCreate: Encodable, Sendable, Hashable {
    public let term: String
    public let edition: String
    public let guarded: Bool

    public init(term: String, edition: String, guarded: Bool) {
        self.term = term
        self.edition = edition
        self.guarded = guarded
    }
}

// MARK: Episode numbering

/// One season-scoped row of the numbering diff.
public struct NumberingDiffRow: Decodable, Sendable, Hashable {
    public let season: Int
    /// `unchanged` · `renumbered` · `retitled` · `added` · `removed`.
    public let kind: String
    public let currentNumber: Int?
    public let alternateNumber: Int?
    public let currentTitle: String?
    public let alternateTitle: String?
}

public struct NumberingRenumbered: Decodable, Sendable, Hashable {
    public let season: Int
    public let fromNumber: Int?
    public let toNumber: Int?
    public let title: String?
}

/// An added or phantom episode (`season`, `number`, `title`).
public struct NumberingEpisodeRef: Decodable, Sendable, Hashable {
    public let season: Int
    public let number: Int?
    public let title: String?
}

/// A file re-linked to the corrected numbering, or one that couldn't be matched.
public struct NumberingFileRef: Decodable, Sendable, Hashable {
    public let mediaFileId: Int
    public let path: String
    public let reason: String?
}

/// `POST /api/v1/library/{id}/numbering/apply` body. The hash pins the previewed diff.
public struct NumberingApplyBody: Encodable, Sendable, Hashable {
    public let source: String?
    public let expectedHash: String

    public init(source: String?, expectedHash: String) {
        self.source = source
        self.expectedHash = expectedHash
    }
}

public struct NumberingApplyDispatch: Decodable, Sendable, Hashable {
    public let runId: Int
}

/// What a completed numbering-apply run did (`CommandRun.numbering_summary`).
public struct NumberingApplyResult: Decodable, Sendable, Hashable {
    public let source: String?
    public let renumbered: [NumberingRenumbered]?
    public let added: [NumberingEpisodeRef]?
    public let relinked: [NumberingFileRef]?
    public let removedPhantoms: [NumberingEpisodeRef]?
    public let unparseable: [NumberingFileRef]?
}
