import Foundation

// What each ticked row can take in a bulk decide (fusionha 0.4.225), ported
// from the web's `routes/manual-import/decide/bulk-caps.ts`. Rows that share
// one library file (`joint_rows`) import together. In a scan of several
// titles the sentences name the title ("The Bear E01"); rows keep the bare code.

public enum ManualImportBulk {

    /// The mock's row kinds: what a row is, for the bulk copy.
    public enum Kind: Sendable, Equatable { case shared, down, new, upgrade }

    public struct Context: Sendable {
        public let rows: [ManualImportRow]
        public let selected: Set<Int>
        public let scan: ManualImportScan?
        public let tallies: [Int: ManualImportDecide.Tally]

        public init(rows: [ManualImportRow], selected: Set<Int>, scan: ManualImportScan?,
                    tallies: [Int: ManualImportDecide.Tally]) {
            self.rows = rows
            self.selected = selected
            self.scan = scan
            self.tallies = tallies
        }

        /// The scan holds more than one title: sentences prefix the title.
        public var multiTitle: Bool { Set(rows.compactMap(\.match.itemId)).count > 1 }
    }

    public struct Caps: Sendable, Equatable {
        public let decided: Bool
        public let kind: Kind
        /// Can import (a shared row only with its whole joint span ticked).
        public let imp: Bool
        /// Imports in bulk: never over a better copy.
        public let bulkImp: Bool
        public let keep: Bool
        public let skip: Bool
        /// The probe proved the release mislabelled (blocklist is recommended).
        public let proof: Bool
    }

    // MARK: Codes

    /// "E02, E04 and E07".
    public static func codeList(_ codes: [String]) -> String {
        guard codes.count > 1, let last = codes.last else { return codes.first ?? "" }
        return codes.dropLast().joined(separator: ", ") + " and " + last
    }

    /// The row's episode code without the season (`E14`), else the title (a
    /// movie), else the file name. `titled` puts the title first ("The Bear E01").
    public static func shortCode(_ r: ManualImportRow, titled: Bool = false) -> String {
        let title = r.match.title ?? r.parsed.title
        guard let code = ManualImportRules.episodeCode(r) else {
            return r.match.itemId != nil ? title ?? r.filename : r.filename
        }
        let short = code.replacingOccurrences(of: #"^S\d+"#, with: "", options: .regularExpression)
        guard titled, r.match.itemId != nil, let title else { return short }
        return "\(title) \(short)"
    }

    static func codes(_ rows: [ManualImportRow], _ ctx: Context) -> String {
        codeList(rows.map { shortCode($0, titled: ctx.multiTitle) })
    }

    // MARK: Caps

    public static func isDecided(_ r: ManualImportRow, _ ctx: Context) -> Bool {
        ManualImportDecide.isDecided(r) || ManualImportDecide.rowFinished(r, ctx.scan, ctx.tallies)
    }

    public static func kind(_ r: ManualImportRow) -> Kind {
        if r.wouldOrphan != nil { return .shared }
        guard let file = r.existingFile else { return .new }
        // No verdict counts as an upgrade; only an explicit `upgrade: false` (or a title block) is down.
        if file.verdict?.upgrade == false || ManualImportRules.titleBlocked(r) { return .down }
        return .upgrade
    }

    /// Blockers a joint import does not lift: a title naming another episode,
    /// no quality, a low or no-confidence match nobody vouched for.
    static func ownBlockers(_ r: ManualImportRow) -> Bool {
        let unvouched = ["low", "none"].contains(r.match.confidence ?? "none") && r.itemOverridden != true
        return ManualImportRules.titleBlocked(r) || r.quality == nil || unvouched
    }

    public static func caps(_ r: ManualImportRow, _ ctx: Context) -> Caps {
        let kind = kind(r)
        if isDecided(r, ctx) {
            return Caps(decided: true, kind: kind, imp: false, bulkImp: false, keep: false, skip: false, proof: false)
        }
        let imp: Bool
        if kind == .shared {
            let byId = Dictionary(ctx.rows.map { ($0.rowId, $0) }, uniquingKeysWith: { a, _ in a })
            let span = r.jointRows ?? []
            imp = !ownBlockers(r) && r.match.itemId != nil && !span.isEmpty && span.allSatisfy { id in
                guard let p = byId[id] else { return false }
                return ctx.selected.contains(id) && !isDecided(p, ctx) && !ownBlockers(p)
            }
        } else {
            imp = ManualImportDecide.importAction(r) != nil && !ownBlockers(r)
        }
        let d = r.held?.detail ?? ctx.scan?.heldDetail
        return Caps(decided: false, kind: kind, imp: imp, bulkImp: imp && kind != .down,
                    keep: r.existingFile != nil, skip: r.existingFile == nil,
                    proof: d?.recommendBlocklist == true && d?.releaseBlocklisted != true)
    }

    /// The probe's proof: "E02 measures 1280×720 but is named 1080p, so this
    /// release is blocklisted and not grabbed again." Nil when measurements differ.
    static func proofDetail(_ rows: [ManualImportRow], _ ctx: Context) -> String? {
        var seen = Set<String>()
        var said = ""
        for r in rows {
            guard let d = r.held?.detail ?? ctx.scan?.heldDetail, let res = d.probedResolution, res.w > 0, res.h > 0,
                  let claimed = ManualImportHeldStrip.claimedNumber(d) else { return nil }
            said = "measures \(res.w)×\(res.h) but is named \(claimed)p"
            seen.insert(said)
        }
        guard seen.count == 1 else { return nil }
        return "\(codes(rows, ctx)) \(said), so this release is blocklisted and not grabbed again."
    }

    /// Undecided rows: what Select all undecided ticks.
    public static func undecided(_ ctx: Context) -> [ManualImportRow] {
        ctx.rows.filter { !isDecided($0, ctx) }
    }
}
