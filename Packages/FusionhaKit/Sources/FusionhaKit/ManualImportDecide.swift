import Foundation

// Decide held files one at a time (fusionha 0.4.202), ported from the web's
// `routes/manual-import/decide/{downloads,findings,keep-options,row-action}.ts`
// and `finish-receipt.ts`: each held download finishes as soon as its own
// rows are decided; a collapsed row shows compact finding chips and its
// actions; a decided row reads as a Done receipt. Nothing can be undone.

public enum ManualImportDecide {

    // MARK: Downloads

    /// Imported, or set to Keep current (the server's rule too).
    public static func isDecided(_ r: ManualImportRow) -> Bool {
        r.committed || r.replaceChoice == "keep_current"
    }

    /// The held download a rescue row belongs to: its own (a bulk scan merges several), else the scan's.
    public static func downloadId(_ r: ManualImportRow, _ scan: ManualImportScan?) -> Int? {
        r.held?.downloadId ?? scan?.downloadId
    }

    public struct Tally: Equatable, Sendable {
        public let id: Int
        public var total: Int
        public var decided: Int
        /// No longer held: imported, finished, left or removed.
        public var finished: Bool
        /// A library file links into it, so a remove only clears it from the queue.
        public var linked: Bool
        /// The Keep current pick stored on the download's kept rows (server, 0.4.225).
        public var disposition: FinishDisposition? = nil
        /// The row whose chosen leave stands for this download, else nil.
        public var leaveRowId: Int? = nil
    }

    /// Per held download, counted live from the rows with the server's `finished` / `library_linked`.
    public static func tallies(_ scan: ManualImportScan?, finishedHere: Set<Int> = []) -> [Int: Tally] {
        let server = Dictionary((scan?.downloads ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [Int: Tally] = [:]
        for r in scan?.rows ?? [] {
            guard let id = downloadId(r, scan) else { continue }
            var t = out[id] ?? Tally(id: id, total: 0, decided: 0,
                                     finished: finishedHere.contains(id) || server[id]?.finished == true,
                                     linked: server[id]?.libraryLinked == true,
                                     disposition: server[id]?.finishDisposition,
                                     leaveRowId: server[id]?.leaveRowId)
            t.total += 1
            if isDecided(r) { t.decided += 1 }
            out[id] = t
        }
        return out
    }

    /// Downloads whose rows are all decided but which still wait to be finished.
    public static func readyToFinish(_ tallies: [Int: Tally]) -> [Tally] {
        tallies.values.filter { !$0.finished && $0.total > 0 && $0.decided == $0.total }.sorted { $0.id < $1.id }
    }

    public static func rowFinished(_ r: ManualImportRow, _ scan: ManualImportScan?, _ tallies: [Int: Tally]) -> Bool {
        downloadId(r, scan).flatMap { tallies[$0]?.finished } == true
    }

    // MARK: Finding chips

    public struct Finding: Equatable, Sendable, Identifiable {
        public enum Tone: Sendable { case finding, library }
        public enum Icon: Sendable { case swap, redirect, warn }
        public let id: String
        public let tone: Tone
        public let icon: Icon?
        public let text: String
        /// The full reason sentence: the accessibility label and the opened row.
        public let sentence: String
    }

    private static func short(_ t: String?) -> String? {
        guard let t else { return nil }
        return t.count > 28 ? String(t.prefix(27)) + "…" : t
    }

    /// The chips that replace the amber reason sentence on a collapsed row:
    /// "⇄ Holds E04 + E05", "↪ Really S06E06 · Mafia" (+ "in library"), "Shared file", or the match advisory.
    public static func findings(_ row: ManualImportRow) -> [Finding] {
        guard !row.committed else { return [] }
        // fusionha words the chips itself since 0.4.204; older servers fall back below.
        if let server = row.finding {
            let icon: Finding.Icon = server.code == "really_episode" ? .redirect : server.code == "holds_episodes" ? .swap : .warn
            return [Finding(id: server.code, tone: .finding, icon: icon, text: server.label, sentence: server.text)]
                + (row.badges ?? []).map { Finding(id: $0.code, tone: .library, icon: nil, text: $0.label, sentence: $0.text) }
        }
        let sentence = ManualImportRules.advisory(row)
        if ManualImportRules.titleBlocked(row), let check = row.titleCheck {
            let code = check.matchesEpisode?.code ?? "another episode"
            let title = short(check.matchesEpisode?.title ?? check.says)
            return [
                Finding(id: "really", tone: .finding, icon: .redirect,
                        text: title.map { "Really \(code) · \($0)" } ?? "Really \(code)", sentence: sentence ?? "The file is \(code)"),
                Finding(id: "lib", tone: .library, icon: nil, text: "in library",
                        sentence: "\(code) is already an episode in your library"),
            ]
        }
        if row.recommended == "assign_episodes", let rec = row.recommendedEpisodes, rec.count > 1 {
            let label = ManualImportRules.episodesLabel(rec)
            return [Finding(id: "holds", tone: .finding, icon: .swap, text: "Holds \(label)", sentence: sentence ?? "This file holds \(label)")]
        }
        if let orphan = row.wouldOrphan {
            return [Finding(id: "shared", tone: .finding, icon: .warn, text: "Shared file",
                            sentence: ManualImportRules.orphanText(row) ?? orphan)]
        }
        guard let sentence else { return [] }
        let alt = row.match.alternative
        let text: String
        if row.corroboration != nil { text = "Title ≠ episode" }
        else if let alt, alt.reason == "also_matches" { text = "Also matches \(short(alt.title) ?? "")" }
        else if let alt { text = "Name matches \(short(alt.title) ?? "")" }
        else { text = "Check the match" }
        return [Finding(id: "advisory", tone: .finding, icon: .warn, text: text, sentence: sentence)]
    }

    /// Every finding sentence of a row, for the opened row.
    public static func sentences(_ row: ManualImportRow) -> [String] {
        var seen = Set<String>()
        return findings(row).filter { $0.tone == .finding }.map(\.sentence).filter { seen.insert($0).inserted }
    }

    // MARK: Keep current

    public struct KeepOption: Equatable, Sendable, Identifiable {
        public let value: FinishDisposition
        public let label: String
        public let detail: String
        public let recommended: Bool
        public var id: String { value.rawValue }
    }

    public struct KeepChoice: Equatable, Sendable {
        /// The current copy's group ("FUZEER").
        public let group: String?
        public let options: [KeepOption]
        /// What the main half does: blocklist only on the probe's proof.
        public let preferred: FinishDisposition
        /// "Keep current", or "Skip this file" with nothing on disk.
        public let verb: String
        public let linked: Bool
        /// The guard already blocklisted the release: remove + blocklist is not offered.
        public let guarded: Bool

        public var preferredOption: KeepOption { options.first { $0.value == preferred } ?? options[0] }
    }

    private static func detail(_ row: ManualImportRow, _ scan: ManualImportScan?) -> HeldDetail? {
        row.held?.detail ?? scan?.heldDetail
    }

    /// The probe PROVED the release is mislabelled (`recommend_blocklist`).
    static func proven(_ row: ManualImportRow, _ scan: ManualImportScan?) -> Bool {
        detail(row, scan)?.recommendBlocklist == true
    }

    private static func mislabelReason(_ row: ManualImportRow, _ scan: ManualImportScan?) -> String? {
        let d = detail(row, scan)
        let group = row.parsed.releaseGroup ?? "this release"
        if d?.recommendBlocklist == true {
            if let d, let res = d.probedResolution, res.w > 0, res.h > 0, let claimed = ManualImportHeldStrip.claimedNumber(d) {
                return "Measures \(res.w)×\(res.h) but is named \(claimed)p, so \(group) is blocklisted and not grabbed again."
            }
            return "The file is not what its name claims, so \(group) is blocklisted and not grabbed again."
        }
        if ManualImportRules.titleBlocked(row), let code = row.titleCheck?.matchesEpisode?.code {
            let named = row.target.episode.map { String(format: "E%02d", $0) } ?? "another episode"
            return "The file is named \(named) but is the \(code) episode, so this release is blocklisted and not grabbed again."
        }
        return nil
    }

    /// The three-way Keep current: remove, remove + blocklist, leave. `saved`
    /// (the pick stored on the server, 0.4.225) is preselected when offered.
    public static func keepChoice(_ row: ManualImportRow, _ scan: ManualImportScan?, linked: Bool,
                                  saved: FinishDisposition? = nil) -> KeepChoice {
        let d = detail(row, scan)
        let guarded = d?.releaseBlocklisted == true
        let why = guarded ? nil : mislabelReason(row, scan)
        let verb = row.existingFile != nil ? "Keep current" : "Skip this file"
        var options = [KeepOption(value: .remove, label: "\(verb) · remove download",
                                  detail: linked ? "Clears it from the queue only; nothing is deleted."
                                      : "Deletes the downloaded files; checked again just before. The release can be grabbed again later.",
                                  recommended: false)]
        if !guarded {
            options.append(KeepOption(value: .removeBlocklist, label: "\(verb) · remove + blocklist",
                                      detail: why ?? "Removes the download and blocklists the release so it is not grabbed again.",
                                      recommended: why != nil))
        }
        options.append(KeepOption(value: .leave, label: "\(verb) · leave the download",
                                  detail: "Only clears the hold. The files and the queue entry are untouched.", recommended: false))
        return KeepChoice(group: row.existingFile?.releaseGroup ?? d?.currentGroup, options: options,
                          preferred: saved.flatMap { s in options.contains { $0.value == s } ? s : nil }
                              ?? (!guarded && proven(row, scan) ? .removeBlocklist : .remove),
                          verb: verb, linked: linked, guarded: guarded)
    }

    /// The finish used when no row picked one: blocklist only on the probe's proof.
    public static func defaultDisposition(_ rows: [ManualImportRow], _ scan: ManualImportScan?) -> FinishDisposition {
        rows.contains { proven($0, scan) && !keepChoice($0, scan, linked: false).guarded } ? .removeBlocklist : .remove
    }

    /// Keep current is the server's pick (the re-match target already holds this exact file).
    public static func keepRecommended(_ row: ManualImportRow) -> Bool {
        row.recommended == "keep_current" && row.existingFile != nil
    }

    // MARK: Row actions

    public struct RowAction: Equatable, Sendable {
        public enum Kind: Sendable { case assign, rematch, importFile }
        public let kind: Kind
        public let label: String
        /// The override sent first; then the row commits.
        public let before: [String: SettingsJSON]?
        public let recommended: Bool
    }

    /// "Import this file": a title naming another episode is dismissed first; never over a shared file.
    public static func importAction(_ row: ManualImportRow) -> RowAction? {
        guard !row.committed, row.match.itemId != nil else { return nil }
        if ManualImportRules.titleBlocked(row) {
            return RowAction(kind: .importFile, label: "Import this file", before: ["dismiss_episode_title": .bool(true)], recommended: false)
        }
        if row.wouldOrphan != nil { return nil }
        return RowAction(kind: .importFile, label: "Import this file", before: nil, recommended: false)
    }

    /// The chip line's leading action: Assign E04 + E05, Re-match to S06E06, else Import this file.
    public static func rowAction(_ row: ManualImportRow) -> RowAction? {
        guard !row.committed, row.match.itemId != nil else { return nil }
        if let assign = ManualImportRules.assignPlan(row) {
            return RowAction(kind: .assign, label: "Assign \(ManualImportRules.episodesLabel(assign.episodes))",
                             before: ["episodes": .array(assign.episodes.map { .int($0) })], recommended: assign.recommended)
        }
        if ManualImportRules.titleBlocked(row), let fields = ManualImportRules.rematchFields(row) {
            let code = row.titleCheck?.matchesEpisode?.code ?? ManualImportRules.episodeCode(row) ?? "the episode"
            return RowAction(kind: .rematch, label: "Re-match to \(code)", before: fields, recommended: row.recommended == "rematch")
        }
        return importAction(row)
    }

    /// A finish error code from a commit's `finishes[]`, in plain words.
    public static func finishCodeMessage(_ code: String?) -> String {
        switch code {
        case "forbidden": return "Only an admin can remove a held download. Leave it, or ask an admin."
        case "rows_open": return "Some files of this download still need a decision."
        case "not_held": return "This download isn't waiting on you any more."
        case "finish_busy": return "This download is being finished already. Try again in a moment."
        default: return "Imported, but the download couldn't be finished. Try Finish download."
        }
    }
}
