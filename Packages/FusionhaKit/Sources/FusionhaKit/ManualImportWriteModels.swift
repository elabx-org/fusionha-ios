import Foundation

// Manual Import's write shapes: the commit, the held download's finish, the
// bulk decide (`POST /scan/{id}/decide`, fusionha 0.4.225) and their enums.

/// `POST /manualimport/commit`: one result per requested row.
public struct ManualImportCommitResult: Decodable, Sendable {
    public let results: [ManualImportCommitRow]
    /// Downloads this commit finished with their `finish_disposition` (0.4.202).
    public let finishes: [ManualImportCommitFinish]?
    public let downloads: [ManualImportDownloadState]?

    public init(results: [ManualImportCommitRow], finishes: [ManualImportCommitFinish]?,
                downloads: [ManualImportDownloadState]?) {
        self.results = results
        self.finishes = finishes
        self.downloads = downloads
    }
}

/// One download a commit (or a decide) tried to finish; `error` is `forbidden`,
/// `rows_open`, `not_held`, `db_busy`, `not_found` or `finish_failed` (the
/// import itself still stands).
public struct ManualImportCommitFinish: Decodable, Sendable, Hashable {
    public let downloadId: Int
    public let mode: String?
    public let blocklisted: Bool?
    public let deletedFiles: Bool?
    public let libraryLinked: Bool?
    public let error: String?

    public var result: FinishRescueResult? {
        mode.map { FinishRescueResult(mode: $0, blocklisted: blocklisted, libraryLinked: libraryLinked) }
    }
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
    /// The file it replaced (e.g. a misfiled one), for the Done receipt.
    public let replacedFile: String?
    public let episodeIds: [Int]?
}

/// `POST /queue/{id}/finish-rescue`: the server decides removed vs finished.
public struct FinishRescueResult: Decodable, Sendable, Hashable {
    /// `removed`, `finished` (the library links into it, nothing deleted) or `left`.
    public let mode: String
    public let blocklisted: Bool?
    public let libraryLinked: Bool?

    public init(mode: String, blocklisted: Bool?, libraryLinked: Bool?) {
        self.mode = mode
        self.blocklisted = blocklisted
        self.libraryLinked = libraryLinked
    }
}

/// How a held download ends once its rows are decided (`finish-rescue`'s `disposition`).
public enum FinishDisposition: String, Sendable, Hashable, CaseIterable {
    case remove, removeBlocklist = "remove_blocklist", leave
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

// MARK: Bulk decide (0.4.225)

/// What one row of a bulk decide does. `keep_current` and `skip` both store
/// Keep current (skip is the word for a row with no copy on disk).
public enum ManualImportDecideAction: String, Sendable, Hashable {
    case importFile = "import", keepCurrent = "keep_current", skip
}

/// `POST /manualimport/scan/{scan_id}/decide`: all or nothing.
public struct ManualImportDecideRequest: Sendable, Equatable {
    public struct Row: Sendable, Equatable {
        public let rowId: Int
        public let action: ManualImportDecideAction
        public init(rowId: Int, action: ManualImportDecideAction) {
            self.rowId = rowId
            self.action = action
        }
    }

    public let rows: [Row]
    /// Per held download, the Keep current pick (only for downloads with a kept row).
    public let dispositions: [Int: FinishDisposition]
    public let importMode: ManualImportMode?

    public init(rows: [Row], dispositions: [Int: FinishDisposition] = [:], importMode: ManualImportMode? = nil) {
        self.rows = rows
        self.dispositions = dispositions
        self.importMode = importMode
    }

    /// The wire body; `dispositions` is left out when empty.
    public var json: SettingsJSON {
        var body: [String: SettingsJSON] = [
            "rows": .array(rows.map { .object(["row_id": .int($0.rowId), "action": .string($0.action.rawValue)]) }),
        ]
        if !dispositions.isEmpty {
            body["dispositions"] = .object(Dictionary(uniqueKeysWithValues: dispositions.map {
                (String($0.key), SettingsJSON.string($0.value.rawValue))
            }))
        }
        if let importMode { body["import_mode"] = .string(importMode.rawValue) }
        return .object(body)
    }
}

/// The decide's answer: the import rows' results, the downloads it finished,
/// the held downloads after it, and the whole scan.
public struct ManualImportDecideResult: Decodable, Sendable {
    public let results: [ManualImportCommitRow]?
    public let finishes: [ManualImportCommitFinish]?
    public let downloads: [ManualImportDownloadState]?
    public let scan: ManualImportScan

    /// The same answer as a commit, for the shared finish handling.
    public var asCommit: ManualImportCommitResult {
        ManualImportCommitResult(results: results ?? [], finishes: finishes, downloads: downloads)
    }
}
