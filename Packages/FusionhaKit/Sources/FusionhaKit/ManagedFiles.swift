import Foundation

// Manage files / Manage episodes (web `ManageExistingFilesDialog`,
// `manage-episodes-vocab.ts`, `use-replace-action.ts`): a title's registered
// files with their release attributes, the bulk editor's fixed vocabulary,
// the scoping that keeps a 4K action off 1080p files, and the endpoints.

/// One registered file (`GET /library/{id}/files` → `ManagedFileRow`).
public struct ManagedFileRow: Decodable, Sendable, Hashable, Identifiable {
    public let fileId: Int
    public let versionId: Int
    public let tier: QualityTier
    public let relativePath: String
    public let season: Int?
    public let episodes: [Int]
    public let releaseGroup: String?
    public let quality: String
    public let languages: [String]
    public let size: Double
    public let releaseType: String?
    public let indexerFlags: [String]
    public let properVersion: Int?
    public let isReal: Bool?
    public let cfScore: Int?
    public let linkUnresolved: Bool?
    public let unresolved: Bool?
    public let analysis: String?
    public let runtimeSeconds: Double?
    /// False for a stray extra file on a version that already has its current file.
    public let isPrimary: Bool?

    public var id: Int { fileId }
}

public struct ManagedFilesResponse: Decodable, Sendable {
    public let rows: [ManagedFileRow]
}

/// One unregistered video under the title's root folders.
public struct LooseFile: Decodable, Sendable, Hashable, Identifiable {
    public let path: String
    public let quality: String?
    public let season: Int?
    public let episodes: [Int]?
    public var id: String { path }
    public var name: String { path.split(separator: "/").last.map(String.init) ?? path }
}

public struct LooseFilesResponse: Decodable, Sendable {
    public let unmatched: [LooseFile]
}

public struct BulkFileDeleteStart: Decodable, Sendable {
    public let runId: Int?
    public let total: Int
}

/// A file as the sheet shows it: scoped, labelled and with its monitored gate.
public struct ManagedFileItem: Sendable, Hashable, Identifiable {
    public let row: ManagedFileRow
    /// Version ∧ season ∧ every episode monitored: Replace (delete + search)
    /// is offered only then, otherwise Clean up (delete only).
    public let monitored: Bool
    public var id: Int { row.fileId }

    public var name: String { row.relativePath.split(separator: "/").last.map(String.init) ?? row.relativePath }
    public var dead: Bool { row.unresolved == true }
    public var unreadable: Bool { !dead && row.analysis == "failed" }
    public var extra: Bool { row.isPrimary == false }
    /// An absent record (no live dead link) goes to remove-and-regrab; a dangling link to the guarded replace.
    public var absent: Bool { row.unresolved == true && row.linkUnresolved != true }

    public var episodeLabel: String? {
        guard let s = row.season, !row.episodes.isEmpty else { return nil }
        let sorted = row.episodes.sorted()
        if sorted.count > 2, let first = sorted.first, let last = sorted.last, last - first == sorted.count - 1 {
            return EpisodeCode.range(season: s, first: first, last: last)
        }
        return EpisodeCode.season(s) + "·" + sorted.map { "E" + EpisodeCode.num($0) }.joined(separator: " ")
    }

    /// `Bluray-1080p · NTb · English · 4.2 GB` style facts.
    public var facts: [String] {
        var out = [DetailText.quality(row.quality)]
        if let g = row.releaseGroup, !g.isEmpty { out.append(g) }
        if !row.languages.isEmpty { out.append(row.languages.joined(separator: ", ")) }
        if let rt = row.releaseType, rt != "unknown" { out.append(ManagedFileVocab.releaseTypeLabel(rt)) }
        out.append(ByteCountFormatter.string(fromByteCount: Int64(row.size), countStyle: .file))
        if let r = ManagedFileVocab.runtime(row.runtimeSeconds) { out.append(r) }
        if let cf = row.cfScore, cf != 0 { out.append("CF \(cf > 0 ? "+" : "")\(cf)") }
        return out
    }
}

public enum ManagedFileRules {
    /// `buildFileRows`: drop files outside the scope's versions and, for one
    /// season, outside it; derive each row's monitored gate.
    public static func items(_ rows: [ManagedFileRow], detail: ItemDetail, scopeVersionIds: Set<Int>?, season: Int?) -> [ManagedFileItem] {
        let versions = Dictionary(detail.editions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let seasons = detail.seasons ?? []
        let seasonOn = Dictionary(seasons.map { ($0.seasonNumber, $0.monitored ?? true) }, uniquingKeysWith: { a, _ in a })
        var episodeOn: [String: Bool] = [:]
        for s in seasons { for e in s.episodes { episodeOn["\(s.seasonNumber):\(e.episodeNumber)"] = e.monitored ?? true } }
        return rows.compactMap { r in
            if let scopeVersionIds, !scopeVersionIds.contains(r.versionId) { return nil }
            if let season, r.season != season { return nil }
            let versionOk = versions[r.versionId]?.monitored ?? true
            let seasonOk = r.season.map { seasonOn[$0] ?? true } ?? true
            let episodesOk = r.season.map { s in r.episodes.allSatisfy { episodeOn["\(s):\($0)"] ?? true } } ?? true
            return ManagedFileItem(row: r, monitored: versionOk && seasonOk && episodesOk)
        }
    }

    /// The one season every selected file sits in (the Episode(s) editor needs it).
    public static func commonSeason(_ items: [ManagedFileItem]) -> Int? {
        let s = Set(items.compactMap(\.row.season))
        return s.count == 1 ? s.first : nil
    }
}

/// The bulk editor's fixed vocabulary (backend `Language`, `IndexerFlag`, `ReleaseType`).
public enum ManagedFileVocab {
    public static let qualities = [
        "REMUX_2160P", "BLURAY_2160P", "WEBDL_2160P", "WEBRIP_2160P", "HDTV_2160P",
        "REMUX_1080P", "BLURAY_1080P", "WEBDL_1080P", "WEBRIP_1080P", "HDTV_1080P", "RAWHD",
        "BLURAY_720P", "WEBDL_720P", "WEBRIP_720P", "HDTV_720P",
        "BLURAY_576P", "BLURAY_480P", "WEBDL_480P", "WEBRIP_480P", "DVD", "DVDR", "SDTV",
        "BRDISK", "DVDSCR", "REGIONAL", "TELECINE", "TELESYNC", "CAM", "WORKPRINT", "UNKNOWN",
    ]
    public static let languages = [
        "Unknown", "Original", "English", "French", "Spanish", "German", "Italian", "Danish", "Dutch", "Japanese",
        "Icelandic", "Chinese", "Russian", "Polish", "Vietnamese", "Swedish", "Norwegian", "Finnish", "Turkish",
        "Portuguese", "Flemish", "Greek", "Korean", "Hungarian", "Hebrew", "Lithuanian", "Czech", "Arabic", "Hindi",
        "Bulgarian", "Malayalam", "Ukrainian", "Slovak", "Thai", "Portuguese (Brazil)", "Spanish (Latino)",
        "Romanian", "Latvian", "Persian", "Catalan", "Croatian", "Serbian", "Bosnian", "Estonian", "Tamil",
        "Indonesian", "Macedonian", "Slovenian",
    ]
    public static let indexerFlags = ["Freeleech", "Halfleech", "DoubleUpload", "Internal", "Scene", "Freeleech75", "Freeleech25", "Nuked"]
    public static let releaseTypes = ["unknown", "singleEpisode", "multiEpisode", "seasonPack"]

    public static func releaseTypeLabel(_ raw: String) -> String {
        switch raw {
        case "singleEpisode": return "Single Episode"
        case "multiEpisode": return "Multi-Episode"
        case "seasonPack": return "Season Pack"
        default: return "Unknown"
        }
    }

    public static func flagLabel(_ raw: String) -> String {
        switch raw {
        case "DoubleUpload": return "Double Upload"
        case "Freeleech75": return "Freeleech 75%"
        case "Freeleech25": return "Freeleech 25%"
        default: return raw
        }
    }

    /// `12m 34s` / `45m`, nil when never probed.
    public static func runtime(_ seconds: Double?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        let m = Int(seconds / 60), s = Int((seconds.truncatingRemainder(dividingBy: 60)).rounded())
        return s > 0 ? "\(m)m \(s)s" : "\(m)m"
    }
}

extension APIClient {
    public func managedFiles(itemId: Int) async throws -> [ManagedFileRow] {
        let r: ManagedFilesResponse = try await get("/api/v1/library/\(itemId)/files")
        return r.rows
    }

    /// Partial: only the keys present change (an empty `release_group` clears it).
    public func bulkEditFiles(itemId: Int, fileIds: [Int], _ fields: [String: SettingsJSON]) async throws -> [ManagedFileRow] {
        var body = fields
        body["file_ids"] = .array(fileIds.map { .int($0) })
        let r: ManagedFilesResponse = try await sendJSON("POST", "/api/v1/library/\(itemId)/files/bulk-edit", .object(body))
        return r.rows
    }

    /// Deletes off the event loop; poll `run(id:)` until it settles.
    public func bulkDeleteFiles(itemId: Int, fileIds: [Int], blocklist: Bool = false, search: Bool = false) async throws -> BulkFileDeleteStart {
        try await sendJSON("POST", "/api/v1/library/\(itemId)/files/bulk-delete", .object([
            "file_ids": .array(fileIds.map { .int($0) }), "blocklist": .bool(blocklist), "search": .bool(search),
        ]))
    }

    /// Delete + monitored re-grab of one dead-linked file; 409 = stood down, nothing deleted.
    public func replaceFile(fileId: Int, force: Bool = false) async throws {
        try await sendJSON("POST", "/api/v1/library/files/\(fileId)/replace",
                           query: force ? [URLQueryItem(name: "force", value: "true")] : [])
    }

    public func bulkReplaceFiles(fileIds: [Int], force: Bool = false) async throws {
        try await sendJSON("POST", "/api/v1/library/files/replace", .object(["file_ids": .array(fileIds.map { .int($0) })]),
                           query: force ? [URLQueryItem(name: "force", value: "true")] : [])
    }

    /// Removes an absent or dangling record, then searches; 422 = the file recovered.
    public func removeAndRegrab(fileId: Int) async throws {
        try await sendJSON("POST", "/api/v1/library/files/\(fileId)/remove-and-regrab")
    }

    /// Moves a stray movie file onto a sibling version; 409 = that version already has a file.
    public func repointFile(itemId: Int, fileId: Int, versionId: Int) async throws {
        try await sendJSON("POST", "/api/v1/library/\(itemId)/files/\(fileId)/repoint", .object(["version_id": .int(versionId)]))
    }

    // MARK: Loose files

    public func looseFiles(itemId: Int) async throws -> [LooseFile] {
        let r: LooseFilesResponse = try await sendJSON("POST", "/api/v1/library/\(itemId)/manage-files", .object([:]))
        return r.unmatched
    }

    /// Attaches a loose file to a version in place; a series also needs the episode.
    public func importLooseFile(itemId: Int, path: String, versionId: Int, episodeId: Int? = nil) async throws -> [LooseFile] {
        var body: [String: SettingsJSON] = ["path": .string(path), "version_id": .int(versionId)]
        if let episodeId { body["episode_id"] = .int(episodeId) }
        let r: LooseFilesResponse = try await sendJSON("POST", "/api/v1/library/\(itemId)/manage-files", .object(body))
        return r.unmatched
    }

    public func deleteLooseFile(itemId: Int, path: String) async throws -> [LooseFile] {
        let r: LooseFilesResponse = try await sendJSON("POST", "/api/v1/library/\(itemId)/manage-files/delete", .object(["path": .string(path)]))
        return r.unmatched
    }
}
