import Foundation

/// The reason strip above a rescue's rows, ported from the web's
/// `routes/manual-import/{held-strip,held-banner}.ts` and `HeldStrip.tsx`
/// (`lines` / `packLines`). One held file reads its reason, guard and CF; a held
/// pack counts its live rows by what they would do, drops zero parts, leads with
/// each download's own reason (H6), and reads Done once nothing is left.
public struct ManualImportHeldStrip: Equatable, Sendable {
    public enum Model: Equatable, Sendable {
        case single(Single)
        case pack(Pack)
        case reason(String)
    }

    public struct Single: Equatable, Sendable {
        public let reason: String
        /// "measures 2560×1440, not 2160p" (the phone's reason).
        public let measured: String?
        public let detail: String?
        /// "would replace your 4K FUZEER copy".
        public let guardLine: String?
        /// "CF 4825 vs your 4875".
        public let cf: String?
    }

    public struct Pack: Equatable, Sendable {
        /// Live rows (undecided, download not finished) by what they would do.
        public let downs: Int
        public let shared: Int
        public let ups: Int
        public let fresh: Int
        public let open: Int
        /// Nothing left to decide: the strip reads Done.
        public let done: Bool
        /// Held rows in the scan (the Done line's "All N decided").
        public let total: Int
        public let oneDownload: Bool
        /// "7 files measure 2560×1440, not the 2160p their names claim." when every downgrade agrees.
        public let reason: String?
        /// H6: each held download's own reason, deduped; titled when the scan merges downloads.
        public let why: [String]
        public let eligible: Int
    }

    public struct Lines: Equatable, Sendable {
        public let line1: [String]
        public let line2: String?
    }

    public let model: Model

    /// `decide` is the footer's `need`, so "to decide" and the primary always agree;
    /// `tallies` makes rows of a finished download count as decided.
    public init?(scan: ManualImportScan, decide: Int? = nil, tallies: [Int: ManualImportDecide.Tally] = [:]) {
        guard scan.isRescue || scan.heldReason != nil else { return nil }
        let rows = scan.rows
        let held = rows.filter { $0.held != nil }
        // One held file (other rows may ride along unheld); a one-row rescue without hold data too.
        if let row = held.count == 1 ? held.first : (held.isEmpty && rows.count == 1 ? rows.first : nil) {
            let reason = Self.reasonShort(scan, row)
            let detail = Self.bannerText(scan, row)
            model = .single(Single(
                reason: reason, measured: Self.measuredShort(scan.heldDetail),
                detail: detail.isEmpty || detail == reason ? nil : detail,
                guardLine: Self.guardLine(scan.heldDetail?.currentGroup ?? row.existingFile?.releaseGroup,
                                          tier: row.target.tier, edition: row.target.edition),
                cf: Self.cfCompareLine(scan.heldDetail?.candidateCf ?? row.incomingCf?.score,
                                       scan.heldDetail?.currentCf ?? row.existingFile?.cfScore)))
            return
        }
        guard held.count >= 2 else {
            model = .reason(Self.reasonShort(scan, held.first))
            return
        }
        // Live = undecided and not of a finished download; each live row lands in one bucket.
        let live = held.filter { !ManualImportDecide.isDecided($0) && !ManualImportDecide.rowFinished($0, scan, tallies) }
        let shared = live.filter { $0.wouldOrphan?.isEmpty == false }
        let rest = live.filter { $0.wouldOrphan?.isEmpty != false }
        let downs = rest.filter { ManualImportRules.titleBlocked($0) || Self.isDowngrade($0) }
        let downIds = Set(downs.map(\.rowId))
        let others = rest.filter { !downIds.contains($0.rowId) }
        let downloads = Set(held.map { $0.held?.downloadId ?? scan.downloadId })
        model = .pack(Pack(
            downs: downs.count, shared: shared.count,
            // Every remaining live row over a current file is an upgrade, importable or not.
            ups: others.filter { $0.existingFile != nil }.count,
            fresh: others.filter { $0.existingFile == nil }.count,
            open: decide ?? live.count, done: live.isEmpty, total: held.count,
            oneDownload: downloads.count <= 1,
            reason: Self.uniformReason(scan, downs.filter { !ManualImportRules.titleBlocked($0) }),
            why: Self.downloadReasons(scan, held),
            eligible: held.filter(Self.bulkEligible).count))
    }

    /// Every held row is decided or its download finished.
    public var done: Bool {
        if case .pack(let p) = model { return p.done }
        return false
    }

    /// Held downgrades the bulk bar can answer (Keep all current / Import all on the web).
    public var bulkEligible: Int {
        if case .pack(let p) = model, !p.done { return p.eligible }
        return 0
    }

    public var line1: [String] { lines(compact: false).line1 }
    public var line2: String? { lines(compact: false).line2 }

    /// The strip's two lines (web `lines`); `compact` is the phone's single-file form.
    public func lines(compact: Bool) -> Lines {
        switch model {
        case .reason(let reason):
            return Lines(line1: [reason], line2: nil)
        case .single(let m):
            if compact {
                let l2 = m.guardLine.map { Self.capitalised($0) + "." } ?? m.detail
                let withCf = m.cf.map { cf in [l2, cf].compactMap { $0 }.joined(separator: " · ") } ?? l2
                return Lines(line1: [m.measured ?? m.reason], line2: withCf)
            }
            return Lines(line1: [m.reason] + [m.guardLine, m.cf].compactMap { $0 }, line2: m.detail)
        case .pack(let m):
            return Self.packLines(m)
        }
    }

    /// The web's `packLines`: zero parts are dropped; desktop and phone read the same.
    static func packLines(_ m: Pack) -> Lines {
        if m.done {
            return Lines(line1: ["All \(m.total) decided"],
                         line2: m.oneDownload ? "The download is finished." : "Every download is finished.")
        }
        var parts: [String] = []
        if m.downs > 0 { parts.append(m.downs == 1 ? "1 file would replace a better copy" : "\(m.downs) files would replace better copies") }
        if m.shared > 0 { parts.append("\(m.shared) \(m.shared == 1 ? "file shares" : "files share") a library file with another episode") }
        if m.ups > 0 { parts.append(m.ups == 1 ? "1 upgrade" : "\(m.ups) upgrades") }
        if m.fresh > 0 { parts.append("\(m.fresh) new") }
        let tail = "\(m.open) still to decide; decide on each row, or tick several and decide them together."
        // H6: the download's own reason leads (one download), or heads the second line (several).
        let one = m.why.count == 1 ? m.why.first : nil
        let why = m.why.count > 1 ? m.why.joined(separator: ". ") + ". " : ""
        return Lines(line1: (one.map { [$0] } ?? []) + parts,
                     line2: why + (m.reason.map { $0 + " " } ?? "") + tail)
    }

    static func capitalised(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    // MARK: Rules

    /// A held row over a current file that is not an upgrade.
    static func isDowngrade(_ r: ManualImportRow) -> Bool {
        r.held != nil && r.existingFile != nil && !ManualImportRules.titleBlocked(r) && r.existingFile?.verdict?.upgrade != true
    }

    /// Uncommitted held downgrades over a current file with a known id.
    public static func bulkEligible(_ r: ManualImportRow) -> Bool {
        !r.committed && isDowngrade(r) && r.existingFile?.mediaFileId != nil
    }

    static func claimedNumber(_ d: HeldDetail) -> Int? {
        if let c = d.claimedResolution { return c }
        guard let q = d.claimedQuality, let r = q.range(of: #"(\d{3,4})p"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return Int(q[r].dropLast())
    }

    static func reasonShort(_ scan: ManualImportScan, _ row: ManualImportRow?) -> String {
        let d = scan.heldDetail
        if d?.kind == "mislabeled_hdr" { return "not an upgrade" }
        if d?.mislabeled == true { return "smaller than its name says" }
        return scan.heldReason ?? row?.held?.reason ?? "needs a manual import"
    }

    /// "measures 2560×1440, not 2160p"; nil without a measured size.
    static func measuredShort(_ d: HeldDetail?) -> String? {
        guard let d, d.mislabeled == true, let claimed = claimedNumber(d),
              let res = d.probedResolution, res.w > 0, res.h > 0 else { return nil }
        return "measures \(res.w)×\(res.h), not \(claimed)p"
    }

    static func bannerText(_ scan: ManualImportScan, _ row: ManualImportRow) -> String {
        guard let d = scan.heldDetail else { return scan.heldReason ?? row.held?.reason ?? "" }
        if d.kind == "mislabeled_hdr" { return HeldCopy.hdrLine(d) }
        if d.mislabeled == true {
            let probed = d.probedQuality ?? "a lower quality"
            guard let claimed = claimedNumber(d) else { return "The file measures as \(probed), below what its name claims." }
            if let res = d.probedResolution, res.w > 0, res.h > 0 {
                return "Name says \(claimed)p, the file measures \(res.w)×\(res.h) (graded \(probed))."
            }
            return "Name says \(claimed)p, the file measures as \(probed)."
        }
        return scan.heldReason ?? row.held?.reason ?? ""
    }

    /// "would replace your 4K FUZEER copy"; nil with no group.
    static func guardLine(_ group: String?, tier: String?, edition: String? = nil) -> String? {
        guard let group, !group.isEmpty else { return nil }
        let short = tier.flatMap(QualityTier.init(rawValue:))?.tierShort
        let slot = short.map { "\($0) \(group)" } ?? group
        // Edition first, like the version label: "Extended · 4K FUZEER".
        return "would replace your \(edition.map { "\($0) · \(slot)" } ?? slot) copy"
    }

    /// "CF 4825 vs your 4875" (web `held-cf.ts`); nil without both scores.
    static func cfCompareLine(_ candidate: Int?, _ current: Int?) -> String? {
        guard let candidate, let current else { return nil }
        let num: (Int) -> String = { $0 < 0 ? "−\(abs($0))" : String($0) }
        return "CF \(num(candidate)) vs your \(num(current))"
    }

    static func uniformReason(_ scan: ManualImportScan, _ downs: [ManualImportRow]) -> String? {
        var keys = Set<String>()
        var line: String?
        for r in downs {
            guard let d = r.held?.detail ?? scan.heldDetail, d.mislabeled == true, let claimed = claimedNumber(d),
                  let res = d.probedResolution, res.w > 0, res.h > 0 else { return nil }
            keys.insert("\(res.w)x\(res.h)@\(claimed)")
            line = "\(res.w)×\(res.h), not the \(claimed)p their names claim."
        }
        guard keys.count == 1, let line else { return nil }
        return "\(downs.count) \(downs.count == 1 ? "file measures" : "files measure") \(line)"
    }

    /// H6: each held download's own reason, once, without "review in Manual Import" (we are
    /// there): the episode-pick, put-in-place and other holds the counts cannot tell.
    static func downloadReasons(_ scan: ManualImportScan, _ held: [ManualImportRow]) -> [String] {
        var order: [Int] = []
        var byDownload: [Int: ManualImportRow] = [:]
        for r in held {
            guard let id = r.held?.downloadId ?? scan.downloadId, byDownload[id] == nil else { continue }
            order.append(id)
            byDownload[id] = r
        }
        let titled = Set(order.map { byDownload[$0]?.match.title }).count > 1
        var out: [String] = []
        for id in order {
            guard let r = byDownload[id] else { continue }
            let detail = r.held != nil ? r.held?.detail : (id == scan.downloadId ? scan.heldDetail : nil)
            if detail?.mislabeled == true { continue }
            if let kind = detail?.kind, kind.hasPrefix("not_an_upgrade") || kind.hasPrefix("mislabeled") { continue }
            let raw = r.held?.reason ?? (id == scan.downloadId ? scan.heldReason : nil)
            let reason = raw?.replacingOccurrences(of: #"[;,.]?\s*review (?:it )?in manual import\.?$"#, with: "",
                                                   options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let reason, !reason.isEmpty else { continue }
            let line = titled ? r.match.title.map { "\($0): \(reason)" } ?? reason : reason
            if !out.contains(line) { out.append(line) }
        }
        return out
    }
}
