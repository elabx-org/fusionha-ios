import Foundation

// Needs you's Fix mode (owner-approved mock, 2026-11-08): what is wrong with
// a version's problem files in plain words, the fix that suits each kind of
// problem, and the words the Replace confirmation uses.

/// Why a file needs the owner.
public enum ManageFixKind: Int, Sendable, CaseIterable, Comparable {
    /// The analysis failed: the file is probably damaged.
    case unreadable
    /// An absent record: nothing at its path any more.
    case gone
    /// A dangling link (a mount or debrid link that stopped answering).
    case deadLink

    public init?(_ item: ManagedFileItem) {
        if item.unreadable { self = .unreadable }
        else if item.absent { self = .gone }
        else if item.dead { self = .deadLink }
        else { return nil }
    }

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// The fix the bar leads with.
public enum ManageFixAction: Sendable, Equatable {
    /// Delete, blocklist the release and search (a damaged file).
    case replace
    /// Search for new copies, nothing blocklisted (the release was fine).
    case searchNew
}

/// The problem files of one kind, as the problem card explains them.
public struct ManageFixGroup: Sendable, Hashable, Identifiable {
    public let kind: ManageFixKind
    public let items: [ManagedFileItem]
    public var id: Int { kind.rawValue }

    private var one: Bool { items.count == 1 }

    /// "1 file can't be read", "2 files are gone from disk".
    public var headline: String {
        let n = items.count
        switch kind {
        case .unreadable: return one ? "1 file can’t be read" : "\(n) files can’t be read"
        case .gone: return one ? "1 file is gone from disk" : "\(n) files are gone from disk"
        case .deadLink: return one ? "1 file’s link is broken" : "\(n) files’ links are broken"
        }
    }

    /// What happened, in plain words. `name` is the one file's episode title.
    public func explanation(name: String?) -> String {
        switch kind {
        case .unreadable:
            if one, let name { return "MediaInfo couldn’t open \(name), so it’s probably damaged." }
            return one ? "MediaInfo couldn’t open the file, so it’s probably damaged."
                : "MediaInfo couldn’t open them, so they’re probably damaged."
        case .gone:
            return one ? "The library still lists it, but nothing is at its path any more (moved or deleted outside fusionha)."
                : "The library still lists them, but nothing is at their path any more (moved or deleted outside fusionha)."
        case .deadLink:
            return one ? "It’s linked from a mount or debrid link that isn’t answering right now."
                : "They’re linked from a mount or debrid link that isn’t answering right now."
        }
    }

    /// The recommended fix (shown bold) and why it suits the problem.
    public var bestFix: (fix: String, why: String) {
        switch kind {
        case .unreadable:
            return one ? ("replace it", "fusionha blocklists this release and searches for another.")
                : ("replace them", "fusionha blocklists these releases and searches for others.")
        case .gone:
            return (one ? "search for a new copy" : "search for new copies",
                    one ? "The release wasn’t at fault, so nothing is blocklisted."
                        : "The releases weren’t at fault, so nothing is blocklisted.")
        case .deadLink:
            return ("re-check the files", "If the link comes back nothing changes; if not, search for new copies.")
        }
    }
}

public enum ManageFix {
    /// The problem files grouped by kind: damaged first, then gone, then dead links.
    public static func groups(_ items: [ManagedFileItem]) -> [ManageFixGroup] {
        var byKind: [ManageFixKind: [ManagedFileItem]] = [:]
        for item in items {
            if let kind = ManageFixKind(item) { byKind[kind, default: []].append(item) }
        }
        return byKind.keys.sorted().map { kind in ManageFixGroup(kind: kind, items: byKind[kind] ?? []) }
    }

    /// A damaged file anywhere leads with Replace; otherwise new copies.
    public static func primary(_ items: [ManagedFileItem]) -> ManageFixAction {
        items.contains(where: \.unreadable) ? .replace : .searchNew
    }

    public static func primaryLabel(_ action: ManageFixAction, count: Int) -> String {
        switch action {
        case .replace: return "Replace"
        case .searchNew: return count == 1 ? "Search for a new copy" : "Search for new copies"
        }
    }

    /// Blocklisting starts on only for damaged files.
    public static func blocklistByDefault(_ items: [ManagedFileItem]) -> Bool {
        items.contains(where: \.unreadable)
    }

    /// "The Morning Show · 1 problem".
    public static func subtitle(title: String, count: Int) -> String {
        "\(title) · \(count == 1 ? "1 problem" : "\(count) problems")"
    }

    /// The orange line under a problem row. `clock` formats `missing_since`.
    public static func reason(_ item: ManagedFileItem, clock: (Date) -> String) -> String? {
        switch ManageFixKind(item) {
        case .unreadable: return "Can’t be read · MediaInfo failed"
        case .gone:
            if let since = ServerTime.parse(item.row.missingSince) { return "Gone from disk since \(clock(since))" }
            return "Gone from disk"
        case .deadLink: return "Link broken · the source isn’t answering"
        case nil: return nil
        }
    }

    /// "Season 4 · 9 other files are fine" (the season only when every
    /// problem sits in it); nil when nothing else is in scope.
    public static func othersLine(problems: [ManagedFileItem], all: [ManagedFileItem]) -> String? {
        let problemIds = Set(problems.map(\.id))
        let seasons = Set(problems.map { $0.row.season ?? -1 })
        if seasons.count == 1, let s = seasons.first, s >= 0 {
            let others = all.filter { !problemIds.contains($0.id) && $0.row.season == s }.count
            if others > 0 { return "\(s == 0 ? "Specials" : "Season \(s)") · \(fine(others))" }
        }
        let others = all.count - problemIds.intersection(Set(all.map(\.id))).count
        return others > 0 ? fine(others) : nil
    }

    private static func fine(_ n: Int) -> String { n == 1 ? "1 other file is fine" : "\(n) other files are fine" }

    // MARK: The confirmation

    /// "Replace Amari?", "Replace 2 files?", "Search for new copies?".
    public static func confirmTitle(_ action: ManageFixAction, count: Int, name: String?) -> String {
        switch action {
        case .replace:
            if count == 1, let name { return "Replace \(name)?" }
            return count == 1 ? "Replace the file?" : "Replace \(count) files?"
        case .searchNew: return count == 1 ? "Search for a new copy?" : "Search for new copies?"
        }
    }

    public static func confirmAction(_ action: ManageFixAction, count: Int) -> String {
        action == .replace ? "Replace" : (count == 1 ? "Search" : "Search for all")
    }

    /// "Deletes the damaged file (4.7 GB) and searches for a new copy now.
    /// Season 4 stays monitored."
    public static func confirmMessage(_ items: [ManagedFileItem], isSeries: Bool) -> String {
        let n = items.count
        let size = DetailText.bytes(items.reduce(0) { $0 + max($1.row.size, 0) })
        let damaged = items.filter(\.unreadable).count
        let copies = n == 1 ? "a new copy" : "new copies"
        let what: String
        if damaged == n {
            what = n == 1 ? "Deletes the damaged file (\(size))" : "Deletes the \(n) damaged files (\(size))"
        } else if damaged == 0 {
            what = n == 1 ? "Clears the missing file’s record" : "Clears the \(n) missing files’ records"
        } else {
            what = "Deletes the damaged files and clears the missing ones (\(size))"
        }
        var parts = ["\(what) and searches for \(copies) now."]
        let monitored = items.filter(\.monitored)
        if monitored.count == n {
            if isSeries {
                let seasons = Array(Set(items.compactMap(\.row.season))).sorted()
                if !seasons.isEmpty {
                    let text = ManageEpisodes.seasonsText(seasons)
                    parts.append("\(text) \(seasons.count == 1 ? "stays" : "stay") monitored.")
                }
            } else {
                parts.append("The movie stays monitored.")
            }
        } else {
            parts.append(monitored.isEmpty ? "Nothing here is monitored, so it’s only cleaned up, not searched."
                         : "Unmonitored files are only cleaned up, not searched.")
        }
        return parts.joined(separator: " ")
    }
}

/// The release `DELETE /library/files/{id}?blocklist=true` would blocklist
/// (`GET /library/files/{id}/blocklist-target`); the route answers null when
/// the file has no owning grab.
public struct FileBlocklistTarget: Decodable, Sendable, Hashable {
    public let releaseTitle: String
    public let transport: String?
    public let hasInfohash: Bool?

    enum CodingKeys: String, CodingKey {
        case releaseTitle, transport = "protocol", hasInfohash
    }

    /// "Usenet", "Torrent".
    public var transportLabel: String? {
        guard let t = transport, !t.isEmpty else { return nil }
        return t.prefix(1).uppercased() + t.dropFirst()
    }
}

extension APIClient {
    public func fileBlocklistTarget(fileId: Int) async throws -> FileBlocklistTarget? {
        try await get("/api/v1/library/files/\(fileId)/blocklist-target")
    }
}
