import Foundation

// Tasks › Needs attention for media analysis (web `enrichment-grouping.ts`,
// `routes/tasks/enrichment/*`): the files the sweep could not analyse,
// grouped by what's wrong, each group with its fixes.

/// One file the sweep gave up on (`EnrichmentIssueRead`).
public struct EnrichmentIssue: Decodable, Sendable, Hashable, Identifiable {
    public let mediaFileId: Int
    public let title: String
    /// `unreadable` · `probe_failed` · `unlinked`
    public let reason: String
    public let path: String?
    public let itemId: Int?
    public let mediaKind: String?
    public let versionId: Int?
    public let episodeId: Int?
    public let seasonNumber: Int?
    public let episodeNumber: Int?

    public var id: Int { mediaFileId }

    public var code: String? {
        guard let s = seasonNumber, let e = episodeNumber else { return nil }
        return EpisodeCode.episode(season: s, episode: e)
    }

    public var fileName: String? {
        guard let path, !path.isEmpty else { return nil }
        return path.split(separator: "/").last.map(String.init)
    }
}

public enum EnrichmentFix: String, Sendable, Hashable {
    case retry, replace, delete, forget

    public var label: String {
        switch self {
        case .retry: return "Retry analysis"
        case .replace: return "Replace"
        case .delete: return "Delete"
        case .forget: return "Forget"
        }
    }

    public var symbol: String {
        switch self {
        case .retry: return "arrow.clockwise"
        case .replace: return "arrow.triangle.2.circlepath"
        case .delete: return "trash"
        case .forget: return "eraser"
        }
    }
}

/// One reason's group: heading, qualifier, the one-tap fix for all, the
/// per-file fixes, and the drill-down copy.
public struct EnrichmentGroup: Sendable, Hashable, Identifiable {
    public enum Tone: Sendable { case blocked, wrong, skip }

    public let reason: String
    public let tone: Tone
    public let heading: String
    public let qualifier: String
    public let fixAll: EnrichmentFix?
    public let fixAllLabel: String
    public let fixes: [EnrichmentFix]
    public let whatsWrong: String
    public let howToFix: String
    public var issues: [EnrichmentIssue]
    public var id: String { reason }

    init(reason: String) {
        self.reason = reason
        issues = []
        switch reason {
        case "unreadable":
            tone = .blocked; heading = "Source file is gone"
            qualifier = "The dead link or debrid source no longer resolves on disk."
            fixAll = .replace; fixAllLabel = "Replace all"; fixes = [.retry, .replace, .delete]
            whatsWrong = "The file’s source no longer resolves on disk: a debrid or rclone target was removed, or the mount was down. A dead file can’t be analysed or played."
            howToFix = "Replace re-downloads it (delete and search). Retry checks again in case the mount is back. Delete removes the file and marks it missing."
        case "probe_failed":
            tone = .wrong; heading = "Couldn’t read media info"
            qualifier = "MediaInfo failed after 3 tries: a corrupt file, or a very cold or slow mount."
            fixAll = .retry; fixAllLabel = "Retry all"; fixes = [.retry, .replace, .delete]
            whatsWrong = "MediaInfo couldn’t read this file after 3 tries. It is likely corrupt, or the mount is very cold or slow."
            howToFix = "Retry tries the probe again. Replace swaps in a fresh release. Delete removes it."
        case "unlinked":
            tone = .skip; heading = "Not linked to a title"
            qualifier = "A leftover import or replace record no sweep can reach."
            fixAll = .forget; fixAllLabel = "Forget all"; fixes = [.forget]
            whatsWrong = "This file record isn’t attached to any title (a leftover of an import or replace). No sweep can reach it."
            howToFix = "Forget drops the stray record. It removes only the database row, never a file on disk."
        default:
            tone = .skip; heading = reason.replacingOccurrences(of: "_", with: " ").capitalized
            qualifier = ""; fixAll = nil; fixAllLabel = ""; fixes = []
            whatsWrong = heading; howToFix = ""
        }
    }

    /// Largest group first; ties keep the server's order.
    public static func groups(_ issues: [EnrichmentIssue]) -> [EnrichmentGroup] {
        var order: [String] = []
        var byReason: [String: EnrichmentGroup] = [:]
        for i in issues {
            if byReason[i.reason] == nil { byReason[i.reason] = EnrichmentGroup(reason: i.reason); order.append(i.reason) }
            byReason[i.reason]?.issues.append(i)
        }
        return order.enumerated()
            .sorted { (byReason[$0.element]!.issues.count, -$0.offset) > (byReason[$1.element]!.issues.count, -$1.offset) }
            .map { byReason[$0.element]! }
    }
}

public struct ForgetUnlinkedResult: Decodable, Sendable {
    public struct Skip: Decodable, Sendable { public let mediaFileId: Int; public let reason: String? }
    public let removed: Int
    public let skipped: [Skip]?
}

private struct RequeueResult: Decodable { let requeued: Int }

extension APIClient {
    /// Puts files back in the analysis backlog; the sweep re-probes them later.
    public func requeueEnrichment(fileIds: [Int]) async throws -> Int {
        let r: RequeueResult = try await sendJSON("POST", "/api/v1/import/enrichment/requeue", .object([
            "scope": .string("failed"), "media_file_ids": .array(fileIds.map { .int($0) }),
        ]))
        return r.requeued
    }

    /// Drops stray records (never a linked file); `deleteFromDisk` also removes the file.
    public func forgetUnlinked(fileIds: [Int], deleteFromDisk: Bool = false) async throws -> ForgetUnlinkedResult {
        try await sendJSON("POST", "/api/v1/library/files/forget-unlinked", .object([
            "media_file_ids": .array(fileIds.map { .int($0) }), "delete_from_disk": .bool(deleteFromDisk),
        ]))
    }
}
