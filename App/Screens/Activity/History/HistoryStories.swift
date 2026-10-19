import SwiftUI
import FusionhaKit

// MARK: - Stories (buildHistoryStories)

/// Everything the History tab derives from the loaded rows, built once per change
/// of the feed (off the main actor) instead of on every body evaluation.
struct HistoryDerived: Sendable {
    var stories: [HistoryStory] = []
    var storyCounts: [HistoryStoryType: Int] = [:]
    var rawCounts: [String: Int] = [:]
    var revision = -1

    static func make(_ entries: [HistoryEntry], revision: Int) -> HistoryDerived {
        let stories = HistoryLogic.build(entries)
        var storyCounts: [HistoryStoryType: Int] = [:]
        for story in stories { storyCounts[story.type, default: 0] += 1 }
        var rawCounts: [String: Int] = [:]
        for entry in entries { rawCounts[HistoryLogic.rawFilter(entry.eventType), default: 0] += 1 }
        return HistoryDerived(stories: stories, storyCounts: storyCounts, rawCounts: rawCounts, revision: revision)
    }
}

enum HistoryLogic {
    struct Parsed: Sendable { let title: String; let seasonEpisode: String?; let episodeName: String? }

    private static let tech = try! NSRegularExpression(
        pattern: #"\b(?:19\d\d|20\d\d|\d{3,4}p|web[ .-]?dl|web[ .-]?rip|webrip|web|blu[ .-]?ray|bdrip|brrip|dvdrip|hdtv|remux|hybrid|x26[45]|h[ .]?26[45]|hevc|avc|hdr10\+?|hdr|dovi|dv|dts(?:[ .-]?hd)?|truehd|atmos|ddp?[0-9]?|dd\+?|eac3|aac|flac|opus|proper|repack|uhd|amzn|nf|dsnp|hmax|atvp|internal|limited|extended|remastered|imax)\b"#,
        options: [.caseInsensitive])
    private static let se = try! NSRegularExpression(pattern: #"\bS(\d{1,2})(?:E(\d{1,3})(?:[-–E]E?(\d{1,3}))?)?\b"#, options: [.caseInsensitive])
    // Compiled once: `replacingOccurrences(options: .regularExpression)` compiles on every call.
    private static let separators = try! NSRegularExpression(pattern: "[._]+")
    private static let brackets = try! NSRegularExpression(pattern: #"[\[\](){}]"#)
    private static let spaces = try! NSRegularExpression(pattern: #"\s+"#)
    private static let edges = try! NSRegularExpression(pattern: #"^[\s-]+|[\s-]+$"#)
    private static let ext = try! NSRegularExpression(pattern: #"\.(mkv|mp4|avi|m4v|ts|mov|wmv)$"#, options: [.caseInsensitive])

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var parseCache: [String: Parsed] = [:]

    private static func replace(_ re: NSRegularExpression, _ s: String, _ with: String) -> String {
        re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: with)
    }

    private static func clean(_ s: String) -> String {
        var t = replace(separators, s, " ")
        t = replace(brackets, t, " ")
        t = replace(spaces, t, " ")
        t = replace(edges, t, "")
        return t.trimmingCharacters(in: .whitespaces)
    }

    private static func techIndex(_ s: String) -> String.Index? {
        let ns = s as NSString
        guard let m = tech.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return Range(m.range, in: s)?.lowerBound
    }

    /// Release-name parsing is pure, so each distinct name is parsed once.
    static func parse(_ raw: String?) -> Parsed {
        let source = (raw ?? "").trimmingCharacters(in: .whitespaces)
        guard !source.isEmpty else { return Parsed(title: "", seasonEpisode: nil, episodeName: nil) }
        cacheLock.lock()
        let hit = parseCache[source]
        cacheLock.unlock()
        if let hit { return hit }
        let parsed = parseUncached(source)
        cacheLock.lock()
        if parseCache.count > 20_000 { parseCache.removeAll(keepingCapacity: true) }
        parseCache[source] = parsed
        cacheLock.unlock()
        return parsed
    }

    private static func parseUncached(_ source: String) -> Parsed {
        let base = replace(ext, source, "")
        let ns = base as NSString
        if let m = se.firstMatch(in: base, range: NSRange(location: 0, length: ns.length)), let r = Range(m.range, in: base) {
            let titleFragment = String(base[..<r.lowerBound])
            let titleCut = techIndex(titleFragment).map { String(titleFragment[..<$0]) } ?? titleFragment
            let rest = String(base[r.upperBound...])
            let epFragment = techIndex(rest).map { String(rest[..<$0]) } ?? rest
            let title = clean(titleCut)
            let name = clean(epFragment)
            return Parsed(title: title.isEmpty ? clean(base) : title,
                          seasonEpisode: String(base[r]).uppercased().replacingOccurrences(of: " ", with: ""),
                          episodeName: name.isEmpty ? nil : name)
        }
        let cut = techIndex(base).map { String(base[..<$0]) } ?? base
        let title = clean(cut)
        return Parsed(title: title.isEmpty ? clean(base) : title, seasonEpisode: nil, episodeName: nil)
    }

    private static func episodeLabel(_ sources: String?...) -> String? {
        var fallback: String?
        for s in sources {
            let p = parse(s)
            guard let se = p.seasonEpisode else { continue }
            if let name = p.episodeName { return "\(se) · \(name)" }
            if fallback == nil { fallback = se }
        }
        return fallback
    }

    private static func leadTitle(_ e: HistoryEntry) -> String {
        if let t = e.itemTitle { return t }
        let p = parse(e.sourceTitle).title
        return p.isEmpty ? "Unknown" : p
    }

    static func failureReason(_ e: HistoryEntry) -> String? {
        guard e.eventType == "GRAB_FAILED" || e.eventType == "DOWNLOAD_FAILED" else { return nil }
        guard let err = e.data?.text("error"), !err.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return err
    }

    /// buildHistoryStories. Linear: grabs/deletes are indexed by download id and
    /// every timestamp is parsed once (it used to be O(n²) with dates parsed
    /// inside the sort comparator).
    static func build(_ entries: [HistoryEntry]) -> [HistoryStory] {
        var dates: [Int: Date] = [:]
        dates.reserveCapacity(entries.count)
        for e in entries { dates[e.id] = ActFmt.date(e.createdAt) ?? .distantPast }
        func date(_ e: HistoryEntry) -> Date { dates[e.id] ?? .distantPast }

        var grabsByDownload: [String: [HistoryEntry]] = [:]
        var deletesByDownload: [String: [HistoryEntry]] = [:]
        var grabs: [HistoryEntry] = [], deletes: [HistoryEntry] = [], imports: [HistoryEntry] = []
        var fails: [HistoryEntry] = [], others: [HistoryEntry] = []
        for e in entries {
            switch e.eventType {
            case "GRABBED":
                grabs.append(e)
                if let d = e.downloadId { grabsByDownload[d, default: []].append(e) }
            case "DELETED":
                deletes.append(e)
                if let d = e.downloadId { deletesByDownload[d, default: []].append(e) }
            case "IMPORTED": imports.append(e)
            case "GRAB_FAILED", "DOWNLOAD_FAILED", "FILE_MOVE_FAILED": fails.append(e)
            case "RENAMED", "FILE_MOVED", "NEEDS_ATTENTION", "RENUMBERED": others.append(e)
            default: break
            }
        }
        var usedGrab = Set<Int>(), usedDel = Set<Int>()
        var stories: [HistoryStory] = []
        stories.reserveCapacity(entries.count)

        func story(_ key: String, _ type: HistoryStoryType, _ e: HistoryEntry, lead: HistoryEntry? = nil,
                   events: [HistoryEntry], old: HistoryEntry? = nil, grab: HistoryEntry? = nil) -> HistoryStory {
            let leadEntry = lead ?? e
            return HistoryStory(
                key: key, type: type, time: leadEntry.createdAt, date: date(leadEntry), mediaItemId: e.mediaItemId, title: leadTitle(e),
                episodeLabel: episodeLabel(old?.sourceTitle, e.sourceTitle, grab?.sourceTitle),
                tier: e.tier ?? grab?.tier ?? old?.tier,
                edition: e.edition ?? grab?.edition ?? old?.edition, posterUrl: e.posterUrl ?? grab?.posterUrl ?? old?.posterUrl,
                oldQuality: old?.quality, oldCf: old?.cfScore,
                newQuality: type == .deleted ? nil : (e.quality ?? grab?.quality),
                newSize: type == .deleted ? nil : (grab?.size ?? (type == .added || type == .upgraded ? nil : e.size)),
                newCf: type == .deleted ? nil : (e.cfScore ?? grab?.cfScore),
                indexer: grab?.indexer ?? (type == .added || type == .upgraded ? nil : e.indexer),
                downloadClient: grab?.downloadClient ?? e.downloadClient,
                failReason: type == .failed ? failureReason(e) : nil,
                releaseTitle: grab?.sourceTitle ?? e.sourceTitle,
                chips: grab?.chips ?? e.chips ?? [], actionEntry: grab ?? e, events: events)
        }

        for imp in imports {
            var grab: HistoryEntry?
            var del: HistoryEntry?
            if let d = imp.downloadId {
                let candidates = grabsByDownload[d] ?? []
                grab = candidates.first { $0.episodeId == imp.episodeId } ?? candidates.first { $0.episodeId == nil }
                del = deletesByDownload[d]?.first { $0.episodeId == imp.episodeId }
            }
            if let grab { usedGrab.insert(grab.id) }
            if let del { usedDel.insert(del.id) }
            let events = [del, imp, grab].compactMap { $0 }.sorted { date($0) > date($1) }
            stories.append(story("imp:\(imp.id)", del != nil ? .upgraded : .added, imp, lead: events.first, events: events, old: del, grab: grab))
        }
        for del in deletes where !usedDel.contains(del.id) {
            let s = story("del:\(del.id)", .deleted, del, events: [del])
            stories.append(HistoryStory(key: s.key, type: s.type, time: s.time, date: s.date, mediaItemId: s.mediaItemId, title: s.title,
                                        episodeLabel: s.episodeLabel, tier: s.tier, edition: s.edition, posterUrl: s.posterUrl, oldQuality: del.quality,
                                        oldCf: del.cfScore, newQuality: nil, newSize: nil, newCf: nil, indexer: nil, downloadClient: nil,
                                        failReason: nil, releaseTitle: del.sourceTitle, chips: del.chips ?? [], actionEntry: del,
                                        events: [del]))
        }
        for grab in grabs where !usedGrab.contains(grab.id) {
            stories.append(story("grab:\(grab.id)", .grabbed, grab, events: [grab], grab: grab))
        }
        for fail in fails { stories.append(story("fail:\(fail.id)", .failed, fail, events: [fail])) }
        for other in others { stories.append(story("other:\(other.id)", .other, other, events: [other])) }
        return stories.sorted { $0.date > $1.date }
    }

    /// historyFilterId for the raw log.
    static func rawFilter(_ type: String) -> String {
        switch type {
        case "GRABBED": return "grabbed"
        case "IMPORTED": return "imported"
        case "GRAB_FAILED", "DOWNLOAD_FAILED", "FILE_MOVE_FAILED": return "failed"
        case "DELETED": return "deleted"
        case "RENAMED", "FILE_MOVED": return "renamed"
        default: return "grabbed"
        }
    }

    static func eventMeta(_ type: String) -> (label: String, color: Color) {
        switch type {
        case "GRABBED": return ("Grabbed", Theme.grab)
        case "IMPORTED": return ("Imported", Theme.done)
        case "GRAB_FAILED": return ("Grab failed", Theme.danger)
        case "DOWNLOAD_FAILED": return ("Download failed", Theme.danger)
        case "DELETED": return ("Deleted", Theme.miss)
        case "RENAMED": return ("Renamed", Theme.edition)
        case "FILE_MOVED": return ("Moved", Theme.edition)
        case "FILE_MOVE_FAILED": return ("Move failed", Theme.danger)
        case "NEEDS_ATTENTION": return ("Needs attention", Theme.miss)
        case "RENUMBERED": return ("Numbering fixed", Theme.edition)
        case "RETARGETED": return ("Moved to edition", Theme.edition)
        default: return (type.replacingOccurrences(of: "_", with: " ").capitalized, Theme.mut)
        }
    }

    static func cfText(_ newCf: Int?, _ oldCf: Int?) -> String? {
        guard let newCf else { return nil }
        guard let oldCf else { return "CF \(newCf.formatted())" }
        let delta = newCf - oldCf
        return "custom-format \(newCf.formatted()) (\(delta >= 0 ? "+" : "")\(delta.formatted()))"
    }
}
