import Foundation

// Manual Import's wire shapes (`/api/v1/manualimport/*`,
// `api/schemas_manual_import*.py`). A scan is a persisted list of file rows;
// each row says what the name claims, what the probe measured, which library
// slot it targets and what is already in that slot. Display-only fields are
// optional so scans from older servers keep decoding.

/// `GET /manualimport/scan/{id}` and every write that returns the scan.
public struct ManualImportScan: Decodable, Sendable, Hashable {
    public let scanId: Int
    public let sourcePath: String
    public let rows: [ManualImportRow]
    public let counts: [String: Int]?
    /// A rescue scan: the held download it was seeded from (the first one of a
    /// bulk rescue), its reason, and the structured "why it's held".
    public let downloadId: Int?
    public let heldReason: String?
    public let heldDetail: HeldDetail?
    /// Rows whose probe outlived the scan's budget; poll `…/probe` while > 0.
    public let probePending: Int?

    public var isRescue: Bool { downloadId != nil }
}

/// One file of a scan.
public struct ManualImportRow: Decodable, Sendable, Hashable, Identifiable {
    public let rowId: Int
    public let sourcePath: String
    public let relativePath: String?
    public let filename: String
    public let size: Double
    public let sourceIsSymlink: Bool?
    public let parsed: ManualImportParsed
    public let match: ManualImportMatch
    public let target: ManualImportTarget
    public let quality: String?
    public let languages: [String]?
    public let releaseType: String?
    /// Why a replace is blocked: it would delete a sibling episode's only file.
    public let wouldOrphan: String?
    /// `ready`, `needs_attention` or `no_match`.
    public let status: String
    public let statusReason: String?
    public let selected: Bool
    public let itemOverridden: Bool?
    public let retargeted: Bool?
    public let retargetNote: String?
    public let committed: Bool
    public let mediaFileId: Int?
    public let probe: ManualImportProbe?
    public let measured: ManualImportMeasured?
    public let mismatchChoice: String?
    public let qualityOverridden: Bool?
    public let nameVsFile: [ManualImportNameFileDiff]?
    public let existingFile: ManualImportExistingFile?
    public let incomingCf: ManualImportIncomingCf?
    public let held: ManualImportHeld?
    public let titleCheckDismissed: Bool?
    public let corroboration: String?
    /// `keep_current` or `import`; nil until the user answers.
    public let replaceChoice: String?

    public var id: Int { rowId }
}

/// What the parser read off the file name.
public struct ManualImportParsed: Decodable, Sendable, Hashable {
    public let title: String?
    public let year: Int?
    public let season: Int?
    public let episodes: [Int]?
    public let absoluteNumbers: [Int]?
    public let quality: String?
    public let edition: String?
    public let releaseGroup: String?
    public let languages: [String]?
    public let resolution: Int?
    public let source: String?
    public let isRemux: Bool?
    public let streamingService: String?
    public let videoCodec: String?
    public let dynamicRange: [String]?
    public let audioLabel: String?
    public let isRepack: Bool?
    public let isProper: Bool?
}

/// The library item a file matched (`itemId` nil for no match).
public struct ManualImportMatch: Decodable, Sendable, Hashable {
    public let itemId: Int?
    public let title: String?
    public let year: Int?
    public let posterUrl: String?
    public let isAnime: Bool?
    /// `high`, `medium`, `low` or `none`.
    public let confidence: String?
    public let alternative: ManualImportAlternative?
}

/// The strongest competing match for a row that is not a high-confidence match.
public struct ManualImportAlternative: Decodable, Sendable, Hashable {
    public let itemId: Int
    public let title: String
    public let year: Int?
    public let kind: String
    /// `also_matches` or `episode_title`.
    public let reason: String
    public let episodeId: Int?
}

/// Where the row imports: the (tier, edition) version and the episode(s).
public struct ManualImportTarget: Decodable, Sendable, Hashable {
    public let kind: String
    public let tier: String
    public let edition: String?
    public let versionExists: Bool?
    public let rootFolderId: Int?
    public let qualityProfileId: Int?
    public let season: Int?
    public let episode: Int?
    public let episodeId: Int?
    public let episodeIds: [Int]?

    public var isSeries: Bool { kind == "series" }
    /// Every episode the file covers (falls back to the single `episodeId`).
    public var coveredEpisodeIds: [Int] {
        if let ids = episodeIds, !ids.isEmpty { return ids }
        return episodeId.map { [$0] } ?? []
    }
}

/// What ffprobe read from the file.
public struct ManualImportProbe: Decodable, Sendable, Hashable {
    /// `ok`, `failed`, `pending` or `unsupported`.
    public let state: String?
    public let error: String?
    public let container: String?
    public let videoCodec: String?
    public let encodeLibrary: String?
    public let width: Int?
    public let height: Int?
    public let bitDepth: Int?
    public let hdrFormat: String?
    public let dvProfile: Int?
    public let audioCodec: String?
    public let audioChannels: Int?
    public let audioLabel: String?
    public let audioLanguages: [String]?
    public let subtitleLanguages: [String]?
    public let runtimeSeconds: Double?

    public var isOK: Bool { state == "ok" }
    public var isPending: Bool { state == "pending" }
}

/// The proof that a name over-claims (a "2160p" file that measures 1440p).
public struct ManualImportMeasured: Decodable, Sendable, Hashable {
    public let claimedResolution: Int?
    public let resolutionBucket: Int?
    public let mislabeled: Bool?
    public let quality: String?
    public let tier: String?
    public let claimedQuality: String?
    public let claimedTier: String?
}

/// One advisory disagreement between the name and the file.
public struct ManualImportNameFileDiff: Decodable, Sendable, Hashable {
    /// `resolution`, `hdr`, `video_codec` or `audio`.
    public let field: String
    public let name: String
    public let file: String
}

/// The upgrade verdict of this file over the one in the slot.
public struct ManualImportReplaceVerdict: Decodable, Sendable, Hashable {
    public let upgrade: Bool?
    public let code: String?
    public let hdrOnly: Bool?
    public let absent: [String]?
    public let claimedCf: Int?
    public let provenCf: Int?
}

/// The file now in the row's slot (what an import would replace).
public struct ManualImportExistingFile: Decodable, Sendable, Hashable {
    public let mediaFileId: Int?
    public let quality: String
    public let size: Double?
    public let releaseGroup: String?
    public let cfScore: Int?
    public let customFormats: [String]?
    public let languages: [String]?
    public let probe: ManualImportProbe?
    public let verdict: ManualImportReplaceVerdict?
}

public struct ManualImportIncomingCf: Decodable, Sendable, Hashable {
    public let score: Int?
    public let formats: [String]?
}

/// A rescue row's held download.
public struct ManualImportHeld: Decodable, Sendable, Hashable {
    public let downloadId: Int
    public let reason: String?
    public let detail: HeldDetail?
}

/// `POST /manualimport/commit`: one result per requested row.
public struct ManualImportCommitResult: Decodable, Sendable {
    public let results: [ManualImportCommitRow]
}

public struct ManualImportCommitRow: Decodable, Sendable, Hashable {
    public let rowId: Int
    public let mediaFileId: Int?
    public let finalMode: String?
    public let note: String?
    public let replaced: Bool?
    public let error: String?
    /// Committed, but the file is not in place yet (the publish journal finishes it).
    public let warning: String?
}

/// `POST /queue/{id}/finish-rescue`: the server decides removed vs finished.
public struct FinishRescueResult: Decodable, Sendable {
    /// `removed` (nothing in the library pointed into it) or `finished`.
    public let mode: String
    public let blocklisted: Bool?
}

/// The commit's import modes (`ManualImportCommitRequest.import_mode`).
public enum ManualImportMode: String, CaseIterable, Sendable, Identifiable {
    case auto = "AUTO", hardlink = "HARDLINK", symlink = "SYMLINK", copy = "COPY", move = "MOVE"

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .auto: return "Auto"
        case .hardlink: return "Hardlink"
        case .symlink: return "Symlink"
        case .copy: return "Copy"
        case .move: return "Move"
        }
    }
    public var hint: String {
        switch self {
        case .auto: return "each file uses its root's mode"
        case .hardlink: return "falls back to copy across filesystems"
        case .symlink: return "debrid/rclone-safe"
        case .copy: return "leave the source"
        case .move: return "remove the source"
        }
    }
}
