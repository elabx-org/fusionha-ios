import Foundation

// The episode-title and runtime checks (fusionha 0.4.193), ported from the
// web's `routes/manual-import/title-check.ts`: a file whose own title names
// another episode of the season is blocked until it is re-matched, the check
// is dismissed, or the current file is kept; a file that runs about two
// episodes is offered the multi-episode assign.
extension ManualImportRules {

    /// The server's title block: the title names another episode and nothing resolved it.
    public static func titleBlocked(_ row: ManualImportRow) -> Bool {
        !row.committed && row.titleCheck?.status == "names_other"
            && row.episodeOverridden != true && row.episodeTitleDismissed != true
            && row.replaceChoice != "keep_current"
    }

    /// "E04 + E05".
    public static func episodesLabel(_ nums: [Int]) -> String {
        nums.map { String(format: "E%02d", $0) }.joined(separator: " + ")
    }

    /// The orphan reason without its "Add E01 …" suggestion when the title names another episode.
    public static func orphanText(_ row: ManualImportRow) -> String? {
        guard let text = row.wouldOrphan, row.titleCheck?.status == "names_other" else { return row.wouldOrphan }
        return text.replacingOccurrences(of: #"Add .+? to this file's episodes or keep the current file\."#,
                                         with: "Keep the current file.", options: .regularExpression)
    }

    /// "44 min, about 2 episodes (each runs 22 min)"; nil under two episodes.
    public static func runtimeLine(_ row: ManualImportRow) -> String? {
        guard let rc = row.runtimeCheck, rc.episodesEstimate >= 2 else { return nil }
        let min = { (s: Int) in Int((Double(s) / 60).rounded()) }
        return "\(min(rc.seconds)) min, about \(rc.episodesEstimate) episodes (each runs \(min(rc.medianEpisodeSeconds)) min)"
    }

    private static let codePattern = try! NSRegularExpression(pattern: #"S(\d+)E(\d+)(?:\D+E?(\d+))?"#,
                                                              options: [.caseInsensitive])

    /// The Re-match override for the episode the title names (`S06E06` / `S06E04-E05`).
    public static func rematchFields(_ row: ManualImportRow) -> [String: SettingsJSON]? {
        let code = row.titleCheck?.matchesEpisode?.code ?? ""
        let ns = code as NSString
        guard let m = codePattern.firstMatch(in: code, range: NSRange(location: 0, length: ns.length)),
              let season = Int(ns.substring(with: m.range(at: 1))),
              let first = Int(ns.substring(with: m.range(at: 2))) else { return nil }
        let last = m.range(at: 3).location == NSNotFound ? first : Int(ns.substring(with: m.range(at: 3))) ?? first
        let episodes = Array(first...max(last, first))
        var fields: [String: SettingsJSON] = ["episodes": .array(episodes.map { .int($0) })]
        if season != row.target.season { fields["season"] = .int(season) }
        return fields
    }

    /// The episodes "Assign" would give the file; `recommended` = the server's pick.
    public static func assignPlan(_ row: ManualImportRow) -> (episodes: [Int], recommended: Bool)? {
        if titleBlocked(row) { return nil }
        if row.recommended == "assign_episodes", let eps = row.recommendedEpisodes, !eps.isEmpty {
            return (eps, true)
        }
        let parsed = row.parsed.episodes ?? []
        let nums = parsed.isEmpty ? (row.target.episode.map { [$0] } ?? []) : parsed
        let have = max(nums.count, row.target.episodeIds?.count ?? 0)
        let est = row.runtimeCheck?.episodesEstimate ?? 0
        guard row.wouldOrphan != nil, est >= 2, have < est, let start = nums.min() else { return nil }
        return (Array(start..<(start + est)), false)
    }

    /// "1 file replaces a two-parter · 3 files are episodes you already have".
    public static func titleSummary(_ rows: [ManualImportRow]) -> String? {
        let live = rows.filter { !$0.committed }
        let two = live.filter { $0.recommended == "assign_episodes" }.count
        let have = live.filter { $0.titleCheck?.status == "names_other" }.count
        var parts: [String] = []
        if two > 0 { parts.append("\(files(two)) \(two == 1 ? "replaces a two-parter" : "replace two-parters")") }
        if have > 0 { parts.append("\(files(have)) \(have == 1 ? "is an episode" : "are episodes") you already have") }
        return live.count >= 2 && !parts.isEmpty ? parts.joined(separator: " · ") : nil
    }

    private static func files(_ n: Int) -> String { n == 1 ? "1 file" : "\(n) files" }
}
