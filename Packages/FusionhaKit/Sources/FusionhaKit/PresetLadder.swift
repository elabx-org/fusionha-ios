import Foundation

// What a captured preset's quality ladder will look like once deployed: the
// model behind the review sheet's ladder (web `preset-ladder.ts`, itself a
// port of the backend's `deploy_preset` → `cf_import` pipeline). Grouped
// members deploy at one shared rank, a group-valued cutoff makes the whole
// group the ceiling, and a group the deployer would refuse is never drawn.

public enum PresetLadderRow: Sendable, Hashable {
    case quality(String)
    /// `index` is the group's position in `quality_groups` (its identity);
    /// members best-first.
    case group(index: Int, name: String, qualities: [String])
}

public struct PresetLadderPreview: Sendable, Hashable {
    /// One entry per rank, best-first.
    public let rows: [PresetLadderRow]
    public let cutoff: String
    /// The group that is the real ceiling: its index, or nil when the ceiling is `cutoff`.
    public let cutoffGroupIndex: Int?
    public let qualityCount: Int

    public var groupCount: Int {
        rows.filter { if case .group = $0 { return true }; return false }.count
    }

    public var cutoffGroup: (name: String, qualities: [String])? {
        guard let cutoffGroupIndex else { return nil }
        for row in rows {
            if case .group(let index, let name, let qualities) = row, index == cutoffGroupIndex { return (name, qualities) }
        }
        return nil
    }
}

public enum PresetLadder {
    /// `QUALITY_ORDER` plus `UNKNOWN`: the drop filter for untrusted manifests.
    public static let known: Set<String> = [
        "REMUX_2160P", "BLURAY_2160P", "WEBDL_2160P", "WEBRIP_2160P", "HDTV_2160P", "REMUX_1080P", "BLURAY_1080P",
        "WEBDL_1080P", "WEBRIP_1080P", "RAWHD", "HDTV_1080P", "BLURAY_720P", "WEBDL_720P", "WEBRIP_720P", "HDTV_720P",
        "BLURAY_576P", "BLURAY_480P", "DVD", "DVDR", "WEBDL_480P", "WEBRIP_480P", "SDTV", "BRDISK", "DVDSCR",
        "REGIONAL", "TELECINE", "TELESYNC", "CAM", "WORKPRINT", "UNKNOWN",
    ]

    private static let webPairs: [(String, String)] = [
        ("WEBDL_2160P", "WEBRIP_2160P"), ("WEBDL_1080P", "WEBRIP_1080P"),
        ("WEBDL_720P", "WEBRIP_720P"), ("WEBDL_480P", "WEBRIP_480P"),
    ]

    private struct Entry { let index: Int; let name: String; let members: [String] }

    /// `_group_entries`: malformed and `allowed: false` entries are skipped
    /// without renumbering the rest.
    private static func entries(_ groups: JSONValue?) -> [Entry] {
        guard let list = groups?.array else { return [] }
        var out: [Entry] = []
        for (index, entry) in list.enumerated() {
            guard let object = entry.object,
                  let name = object["name"]?.string?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { continue }
            if let allowed = object["allowed"], !truthy(allowed) { continue }
            guard let qualities = object["qualities"]?.array else { continue }
            out.append(Entry(index: index, name: name, members: qualities.compactMap(\.string).filter { known.contains($0) }))
        }
        return out
    }

    /// JavaScript truthiness, for the hand-editable `allowed` flag.
    private static func truthy(_ value: JSONValue) -> Bool {
        switch value {
        case .null: return false
        case .bool(let b): return b
        case .number(let n): return n != 0
        case .string(let s): return !s.isEmpty
        case .array, .object: return true
        }
    }

    /// `_carries_group_structure`: `[]` counts; a missing key or a list of non-objects is legacy.
    private static func carriesGroups(_ groups: JSONValue?) -> Bool {
        guard let list = groups?.array else { return false }
        return list.isEmpty || list.contains { $0.object != nil }
    }

    /// `normalise_ladder_order`: dedupe; legacy manifests also fix inverted WEB-DL/WEBRip pairs.
    private static func normalise(_ allowed: [String], authoritative: Bool) -> [String] {
        var seen = Set<String>()
        var order = allowed.filter { seen.insert($0).inserted }
        if authoritative { return order }
        for (webdl, webrip) in webPairs {
            guard let dl = order.firstIndex(of: webdl), let rip = order.firstIndex(of: webrip) else { continue }
            if dl < rip { order[dl] = webrip; order[rip] = webdl }
        }
        return order
    }

    /// `_membership`: quality → group index, refusing non-contiguous groups.
    private static func membership(_ entries: [Entry], _ allowed: [String]) -> [String: Int] {
        let allowedSet = Set(allowed)
        var claimed: [String: Int] = [:]
        for entry in entries {
            for q in entry.members where allowedSet.contains(q) && claimed[q] == nil { claimed[q] = entry.index }
        }
        var spots: [Int: [Int]] = [:]
        for (position, q) in allowed.enumerated() {
            if let index = claimed[q] { spots[index, default: []].append(position) }
        }
        for (index, positions) in spots {
            guard let first = positions.first, let last = positions.last else { continue }
            if last - first + 1 != positions.count {
                for (q, owner) in claimed where owner == index { claimed[q] = nil }
            }
        }
        return claimed
    }

    public static func preview(_ manifest: PresetManifest) -> PresetLadderPreview {
        let parsed = entries(manifest.qualityGroups)
        let names = Dictionary(parsed.map { ($0.index, $0.name) }, uniquingKeysWith: { first, _ in first })
        let declared = manifest.allowedQualities.filter { known.contains($0) }
        var allowed = normalise(declared, authoritative: carriesGroups(manifest.qualityGroups))
        let cutoff = known.contains(manifest.cutoff) ? manifest.cutoff : (allowed.last ?? "UNKNOWN")
        if allowed.isEmpty { allowed = [cutoff] }

        let claimed = membership(parsed, allowed)
        var groupMembers: [Int: [String]] = [:]
        var worstFirst: [(kind: String, value: String, index: Int)] = []
        for q in allowed {
            guard let index = claimed[q] else { worstFirst.append(("q", q, -1)); continue }
            if groupMembers[index] == nil { worstFirst.append(("g", "", index)) }
            groupMembers[index, default: []].append(q)
        }
        let rows: [PresetLadderRow] = worstFirst.reversed().map { slot -> PresetLadderRow in
            slot.kind == "q" ? .quality(slot.value)
                : .group(index: slot.index, name: names[slot.index] ?? "", qualities: Array((groupMembers[slot.index] ?? []).reversed()))
        }
        return PresetLadderPreview(rows: rows, cutoff: cutoff,
                                   cutoffGroupIndex: cutoffGroup(manifest, owner: claimed[cutoff], names: names),
                                   qualityCount: allowed.count)
    }

    /// `resolve_cutoff_group`: confirm the group owning the cutoff against what the capture recorded.
    private static func cutoffGroup(_ manifest: PresetManifest, owner: Int?, names: [Int: String]) -> Int? {
        if let index = manifest.cutoffGroupIndex, !index.isNull {
            guard let n = index.double, n.rounded() == n else { return nil }
            return owner == Int(n) ? owner : nil
        }
        guard let owner else { return nil }
        let recorded = manifest.cutoffGroup?.string?.trimmingCharacters(in: .whitespaces) ?? ""
        return recorded.isEmpty || names[owner] == recorded ? owner : nil
    }
}
