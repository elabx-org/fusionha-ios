import Foundation

/// What `POST /api/v1/blocklist` should be told to block: exactly one of a
/// History event id or a Download primary key (web `lib/api/blocklist-target.ts`).
public enum BlocklistTarget: Equatable, Sendable {
    /// `keepsCurrentFile`: a HELD row; the slot's current file is the one the
    /// hold kept, so "Delete the current file" is never offered.
    case history(id: Int, keepsCurrentFile: Bool)
    case download(id: Int)

    public var keepsCurrentFile: Bool {
        if case .history(_, true) = self { return true }
        return false
    }

    public func body(search: Bool, deleteFile: Bool) -> BlocklistCreate {
        switch self {
        case .history(let id, let keeps):
            return BlocklistCreate(historyId: id, search: search, deleteCurrentFile: deleteFile && !keeps)
        case .download(let id):
            return BlocklistCreate(downloadId: id, search: search, deleteCurrentFile: deleteFile)
        }
    }

    /// Event types that can ever carry a release (the server's allowlist).
    static let releaseEvents: Set<String> = ["GRABBED", "IMPORTED", "DOWNLOAD_FAILED", "GRAB_FAILED", "HELD"]

    /// The web's `historyBlocklistTarget`: one predicate for every surface.
    /// `blocklistable` is server truth; the guid branch is a fallback for a
    /// server predating the flag. nil when the row carries no release.
    public static func history(id: Int, eventType: String, versionId: Int?, guid: String?,
                               blocklistable: Bool?) -> BlocklistTarget? {
        guard releaseEvents.contains(eventType) else { return nil }
        if blocklistable == true { return .history(id: id, keepsCurrentFile: eventType == "HELD") }
        if blocklistable == false { return nil }
        guard eventType == "GRABBED", let guid, !guid.isEmpty, versionId != nil else { return nil }
        return .history(id: id, keepsCurrentFile: false)
    }

    /// A queue row always has a live Download.
    public static func queue(downloadId: Int) -> BlocklistTarget { .download(id: downloadId) }
}

public extension HistoryEntry {
    /// The manual-blocklist target for this row, or nil when it carries no release.
    var blocklistTarget: BlocklistTarget? {
        BlocklistTarget.history(id: id, eventType: eventType, versionId: editionId,
                                guid: data?.text("guid"), blocklistable: blocklistable)
    }
}
