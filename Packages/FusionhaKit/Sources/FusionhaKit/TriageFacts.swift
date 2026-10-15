import Foundation

/// Every string the approver's decision card shows (web `triage-facts.ts`),
/// built from a request and its triage so the copy is unit-tested.
public enum TriageFacts {
    public enum Tone: Sendable, Hashable { case ok, warn }

    public struct Tile: Sendable, Hashable {
        public let value: String
        public let sub: String?
        public let tone: Tone?
        /// The phone deck's shorter value, where it differs.
        public let short: String
    }

    public struct FreeAfter: Sendable, Hashable {
        public let value: String
        public let of: String?
        public let sub: String?
        public let tone: Tone?
        public let usedPct: Double
        public let addPct: Double
    }

    public static let ownRequestNote = "This is your own request — another approver decides it."
    public static let setupMissingNote = "Set the Add defaults for this version, or use Adjust to pick a root folder and profile."

    // MARK: Time and names

    /// "12 m", "3 h", "2 d" (empty when the time is missing).
    public static func compactAge(_ iso: String?, now: Date = Date()) -> String {
        guard let iso, let then = ServerTime.parse(iso) else { return "" }
        let minutes = max(0, Int(now.timeIntervalSince(then) / 60))
        if minutes < 60 { return "\(minutes) m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) h" }
        return "\(hours / 24) d"
    }

    public static func oldestAge(_ requests: [MediaRequest], now: Date = Date()) -> String {
        compactAge(requests.compactMap(\.requestedAt).min(), now: now)
    }

    public static func firstName(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? name
    }

    public static func requesterName(_ r: MediaRequest) -> String {
        r.requester?.displayName ?? "Deleted user"
    }

    public static func shortDay(_ isoDate: String) -> String {
        let parts = isoDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 3 else { return isoDate }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(parts[2]) \(months[max(0, min(11, parts[1] - 1))])"
    }

    /// "Approve HD + 4K".
    public static func approveLabel(_ tiers: [QualityTier]) -> String {
        "Approve " + tiers.map { $0 == .uhd ? "4K" : "HD" }.joined(separator: " + ")
    }

    public static func kindText(_ r: MediaRequest, isAnime: Bool?) -> String {
        let base = RequestLifecycle.kindLabel(r)
        guard isAnime == true else { return base }
        return r.kind == .movie ? "Anime movie" : base.replacingOccurrences(of: "Series", with: "Anime series",
                                                                            options: .anchored)
    }

    // MARK: Tiles

    public static func size(_ t: RequestTriage?) -> Tile {
        let sizes = (t?.versions ?? []).map(\.estimateBytes)
        guard t != nil, !sizes.isEmpty, sizes.allSatisfy({ $0 != nil }) else {
            return Tile(value: "—", sub: t?.metaPending == true ? "Looking up runtime…" : "Runtime unknown", tone: nil, short: "—")
        }
        let value = sizes.map { "~" + DetailText.bytes($0) }.joined(separator: " + ")
        return Tile(value: value, sub: "at the profile’s preferred size", tone: nil, short: value)
    }

    /// The disk with the least room left.
    public static func tightestDisk(_ disks: [RequestTriage.Disk]) -> RequestTriage.Disk? {
        disks.filter { $0.freeAfterBytes != nil }.min { ($0.freeAfterBytes ?? 0) < ($1.freeAfterBytes ?? 0) } ?? disks.first
    }

    public static func freeAfter(_ t: RequestTriage?) -> FreeAfter {
        guard let t, let disk = tightestDisk(t.disks) else {
            return FreeAfter(value: "—", of: nil, sub: t == nil ? nil : "No default root folder", tone: nil, usedPct: 0, addPct: 0)
        }
        let root = disk.rootPaths.first ?? "the root folder"
        guard let free = disk.freeBytes, let total = disk.totalBytes else {
            return FreeAfter(value: "—", of: nil, sub: "Couldn’t read \(root)", tone: .warn, usedPct: 0, addPct: 0)
        }
        let used = total > 0 ? min(100, (total - free) / total * 100) : 0
        let add = total > 0 ? min(100 - used, disk.neededBytes / total * 100) : 0
        let after = disk.freeAfterBytes ?? free
        if after < 0 {
            return FreeAfter(value: "Not enough space",
                             of: nil,
                             sub: "needs ~\(DetailText.bytes(disk.neededBytes)) · \(DetailText.bytes(free)) free on \(root)",
                             tone: .warn, usedPct: used, addPct: add)
        }
        let tib = 1024.0 * 1024 * 1024 * 1024
        let value = after < tib ? DetailText.bytes(after) : String(format: "%.2f TB", after / tib)
        let sub = t.disks.count > 1 ? "on \(root)" : (disk.estimateComplete == false ? "size not counted yet" : nil)
        return FreeAfter(value: value, of: "of \(DetailText.bytes(total))", sub: sub, tone: nil, usedPct: used, addPct: add)
    }

    public static func lowSpaceMessage(_ t: RequestTriage?) -> String? {
        guard let t, t.lowSpace, let disk = tightestDisk(t.disks), let free = disk.freeBytes else { return nil }
        let root = disk.rootPaths.first ?? "the root folder"
        return "Not enough space on \(root) — needs ~\(DetailText.bytes(disk.neededBytes)), \(DetailText.bytes(free)) free."
    }

    /// 4K RELEASE; `checkable` when "Check now" can probe it.
    public static func fourK(_ t: RequestTriage?) -> (tile: Tile, checkable: Bool) {
        switch t?.fourK.state {
        case "available":
            let what = t?.fourK.bestQuality.map { DetailText.quality($0) } ?? "2160p"
            let n = t?.fourK.indexers ?? 0
            let where_ = n > 0 ? " on \(n) indexer\(n == 1 ? "" : "s")" : ""
            return (Tile(value: "Available", sub: what + where_, tone: .ok, short: "Yes"), false)
        case "tracked":
            return (Tile(value: "Already tracked", sub: "A UHD·4K version exists", tone: nil, short: "Tracked"), false)
        case "unseen":
            return (Tile(value: "Not yet", sub: "Only 1080p releases so far", tone: nil, short: "Not yet"), true)
        default:
            return (Tile(value: "Not checked", sub: "Not in the library yet", tone: nil, short: "Not checked"), true)
        }
    }

    public static func release(_ t: RequestTriage?) -> Tile {
        guard let r = t?.release else { return Tile(value: "—", sub: nil, tone: nil, short: "—") }
        switch r.state {
        case "out":
            return Tile(value: r.label, sub: "Grabs immediately on approve", tone: .ok, short: "Out now")
        case "upcoming":
            return Tile(value: r.label, sub: "Will wait, then grab automatically", tone: .warn,
                        short: r.availableFrom.map { "Est. \(shortDay($0))" } ?? r.label)
        default:
            return Tile(value: r.label, sub: "Grabs once it’s released", tone: nil, short: r.label)
        }
    }

    public static func demandText(_ t: RequestTriage?, ownerName: String) -> String {
        let n = t?.demand.count ?? 1
        return n <= 1 ? "Just \(firstName(ownerName))" : "\(n) people want this"
    }

    public static func trackLine(_ t: RequestTriage?) -> String? {
        guard let t else { return nil }
        let n = t.trackRecord.requests30d, d = t.trackRecord.declined30d
        return "\(n) request\(n == 1 ? "" : "s") · \(d) declined"
    }

    public static func trackBadge(_ t: RequestTriage?, role: String?) -> (label: String, trusted: Bool)? {
        if t?.trackRecord.trusted == true { return ("Trusted", true) }
        return role.map { ($0, false) }
    }

    /// Approve waits for this row's triage, so the space and setup guards are never skipped.
    public static func loaded(_ t: RequestTriage?) -> Bool { t != nil }

    public static func setupMissing(_ t: RequestTriage?) -> Bool {
        (t?.versions ?? []).contains { !$0.configured }
    }

    /// Everyone asking: the owner, then joiners (approvers see names).
    public static func people(_ r: MediaRequest) -> [RequestPerson] {
        var seen = Set<Int>()
        var out: [RequestPerson] = []
        for person in [r.requester].compactMap({ $0 }) + (r.joiners ?? []) {
            if let id = person.id {
                guard seen.insert(id).inserted else { continue }
            }
            out.append(person)
        }
        return out
    }

    // MARK: Bulk

    /// "2 already decided · 1 withdrawn".
    public static func bulkFailureText(_ errors: [String?]) -> String {
        let words = ["own_request": "your own request", "not_rejectable": "already decided",
                     "withdrawn": "withdrawn", "not_found": "no longer exists"]
        var order: [String] = []
        var counts: [String: Int] = [:]
        for e in errors {
            let word = words[e ?? ""] ?? "couldn’t be decided"
            if counts[word] == nil { order.append(word) }
            counts[word, default: 0] += 1
        }
        return order.map { "\(counts[$0]!) \($0)" }.joined(separator: " · ")
    }

    /// Sums the selection's estimates per filesystem and names the ones that run short.
    public static func bulkLowSpace(_ triage: [Int: RequestTriage], ids: [Int]) -> String? {
        var order: [String] = []
        var roots: [String: (label: String, needed: Double, free: Double)] = [:]
        for id in ids {
            for d in triage[id]?.disks ?? [] {
                guard !d.rootPaths.isEmpty, let free = d.freeBytes else { continue }
                let key = d.rootPaths.joined(separator: "\u{0}")
                if var entry = roots[key] {
                    entry.needed += d.neededBytes
                    entry.free = min(entry.free, free)
                    roots[key] = entry
                } else {
                    order.append(key)
                    roots[key] = (d.rootPaths[0], d.neededBytes, free)
                }
            }
        }
        let short = order.compactMap { roots[$0] }.filter { $0.needed > $0.free }.map(\.label)
        return short.isEmpty ? nil : "Not enough space on \(short.joined(separator: ", ")) for all \(ids.count)."
    }

    /// A single decision's refusal, in words (never the server's own text).
    public static func failureMessage(code: String?, status: Int?) -> String {
        switch code {
        case "own_request": return "It’s your own request — another approver decides it."
        case "not_rejectable": return "It was already decided."
        case "withdrawn": return "It was withdrawn."
        default: break
        }
        switch status {
        case 422: return "Set up Add defaults for this kind and tier in Settings first."
        case 404: return "It no longer exists."
        case 409: return "It was already decided."
        default: return "Please try again."
        }
    }
}
