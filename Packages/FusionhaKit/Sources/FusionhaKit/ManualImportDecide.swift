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
    }

    /// Per held download, counted live from the rows with the server's `finished` / `library_linked`.
    public static func tallies(_ scan: ManualImportScan?, finishedHere: Set<Int> = []) -> [Int: Tally] {
        let server = Dictionary((scan?.downloads ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [Int: Tally] = [:]
        for r in scan?.rows ?? [] {
            guard let id = downloadId(r, scan) else { continue }
            var t = out[id] ?? Tally(id: id, total: 0, decided: 0,
                                     finished: finishedHere.contains(id) || server[id]?.finished == true,
                                     linked: server[id]?.libraryLinked == true)
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

    /// The three-way Keep current: remove, remove + blocklist, leave.
    public static func keepChoice(_ row: ManualImportRow, _ scan: ManualImportScan?, linked: Bool) -> KeepChoice {
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
                          preferred: !guarded && proven(row, scan) ? .removeBlocklist : .remove,
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

    // MARK: Receipts

    public struct Receipt: Equatable, Sendable {
        /// "Kept your FUZEER copy" / "Imported as S06E06".
        public let title: String
        /// "download removed · release blocklisted" / "replaced The.Lover.mkv".
        public let detail: String?
    }

    public static func finishDetail(_ res: FinishRescueResult) -> String {
        switch res.mode {
        case "left": return "download left as it is"
        case "removed": return res.blocklisted == true ? "download removed · release blocklisted" : "download removed"
        default: return res.libraryLinked == true ? "download finished · nothing deleted, your library links into it" : "download finished · nothing deleted"
        }
    }

    public static func keptReceipt(group: String?, _ res: FinishRescueResult, skipped: Bool) -> Receipt {
        Receipt(title: skipped ? "Skipped this file" : group.map { "Kept your \($0) copy" } ?? "Kept your copy",
                detail: finishDetail(res))
    }

    private static func place(_ row: ManualImportRow, _ result: ManualImportCommitRow?) -> String {
        if let code = ManualImportRules.episodeCode(row) { return code }
        if row.target.kind == "movie" { return row.match.title ?? "the movie" }
        if let n = result?.episodeIds?.count, n > 0 { return "\(n) episodes" }
        return "this episode"
    }

    public static func importedReceipt(_ row: ManualImportRow, _ result: ManualImportCommitRow? = nil) -> Receipt {
        let said = row.titleCheck?.status == "names_other" ? nil : row.titleCheck?.says
        let name = row.target.isSeries ? said.map { " \($0)" } ?? "" : ""
        return Receipt(title: "Imported as \(place(row, result))\(name)", detail: result?.replacedFile.map { "replaced \($0)" })
    }

    /// A receipt rebuilt from the scan alone (the sheet was reopened after the finish).
    public static func fallbackReceipt(_ row: ManualImportRow) -> Receipt {
        if row.committed { return importedReceipt(row) }
        let title = row.existingFile == nil ? "Skipped this file"
            : row.existingFile?.releaseGroup.map { "Kept your \($0) copy" } ?? "Kept your copy"
        return Receipt(title: title, detail: "download finished")
    }

    /// "Show S01 pack" for the pack progress line.
    public static func packName(_ rows: [ManualImportRow]) -> String {
        let r = rows.first
        let title = r?.match.title ?? r?.parsed.title ?? "Season"
        guard let season = r?.target.season ?? r?.parsed.season else { return "\(title) pack" }
        return "\(title) S\(String(format: "%02d", season)) pack"
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

/// What the rescue's footer primary does (fusionha 0.4.202 `finishPlan`).
public struct ManualImportFinishPlan: Equatable, Sendable {
    /// need: a row has no decision · importing: commit the ticked rows · keep:
    /// every row is decided but a download still waits for its finish · done.
    public enum Kind: Sendable { case need, importing, keep, done }
    public let kind: Kind
    public let imports: Int
    public let kept: Int
    public let need: Int
    public let done: Int
    public let label: String
    public let disabled: Bool

    /// A row that still blocks its download's finish (the footer's `need` and the strip's "to decide").
    public static func needsDecision(_ r: ManualImportRow, selected: Set<Int>, finished: (ManualImportRow) -> Bool = { _ in false }) -> Bool {
        !r.committed && !finished(r) && r.replaceChoice != "keep_current"
            && !(selected.contains(r.rowId) && ManualImportRules.isImportable(r))
    }

    public init(rows: [ManualImportRow], selected: Set<Int>,
                finished: (ManualImportRow) -> Bool = { _ in false }, pending: Int = 0) {
        let open = rows.filter { !$0.committed && !finished($0) }
        let rest = open.filter { $0.replaceChoice != "keep_current" }
        imports = rest.filter { selected.contains($0.rowId) && ManualImportRules.isImportable($0) }.count
        need = rest.filter { Self.needsDecision($0, selected: selected, finished: finished) }.count
        kept = open.count - rest.count
        done = rows.filter(\.committed).count
        let plan: (Kind, String, Bool)
        if imports > 0 {
            plan = (.importing, "Force import \(imports)", false)
        } else if need > 0 {
            plan = (.need, need == 1 ? "1 file needs a decision" : "\(need) files need a decision", true)
        } else if pending > 0 {
            plan = (.keep, pending == 1 ? "Finish download" : "Finish \(pending) downloads", false)
        } else {
            plan = (.done, "Done", false)
        }
        kind = plan.0
        label = plan.1
        disabled = plan.2
    }

    public var hint: String? {
        switch kind {
        case .need: return "Each download finishes as soon as its own rows are decided."
        case .keep: return "Every row is decided · a download still needs its finish."
        case .done: return "Every download is finished."
        case .importing: return nil
        }
    }
}
