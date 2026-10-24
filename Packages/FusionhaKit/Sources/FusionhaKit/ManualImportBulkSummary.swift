import Foundation

/// The selection's summary for the bulk bar, the Decide menu and the open
/// Duo's panel (fusionha 0.4.225, the web's `bulk-summary.ts`): what each
/// ticked file can take, the outcome sentences, the reasons an action is off,
/// and the Keep current dispositions of the held downloads. Outside a held
/// scan Keep current has no disposition ("nothing imported, your library file stays").
public struct ManualImportBulkSummary: Sendable {

    public struct Disposition: Sendable, Equatable, Identifiable {
        public let value: FinishDisposition
        public let label: String
        public let detail: String
        /// The pre-pick when it isn't the plain default (never on remove).
        public let recommended: Bool
        /// Why it can't be picked (a leave stands on another row), else nil.
        public let off: String?
        public var id: String { value.rawValue }
    }

    /// One picked row in the open Duo's breakdown ("E02  keep current (not an upgrade)").
    public struct Line: Sendable, Equatable, Identifiable {
        public let rowId: Int
        public let code: String
        public let text: String
        public var id: Int { rowId }
    }

    public struct Reasons: Sendable, Equatable {
        public var imp: String?
        public var keep: String?
        public var skip: String?
        /// Some keep downloads have a standing leave: those are left.
        public var leave: String?
        /// Every line, import's first (the outcome card under the outcome).
        public var all: [String] { [imp, keep, skip, leave].compactMap { $0 } }
    }

    /// Ticked rows (decided ones included).
    public let n: Int
    public let open: [ManualImportRow]
    public let decided: [ManualImportRow]
    public let imp: [ManualImportRow]
    public let keep: [ManualImportRow]
    public let skip: [ManualImportRow]
    public let reasons: Reasons
    public let decidedNote: String?
    /// The scan holds a download: Keep current offers its dispositions.
    public let held: Bool
    public let dispositions: [Disposition]
    public let preferred: FinishDisposition
    public let leaveRowCode: String?
    public let impOutcome: String?
    public let skipOutcome: String?
    public let lines: [Line]
    /// The keep rows' downloads, and which of them carry a standing leave.
    let keepDownloads: [Int]
    let leaveDownloads: Set<Int>
    private let keepTail: @Sendable (FinishDisposition) -> String?

    /// `"3"` when it is the whole open selection, else `"1 of 4"`.
    public func of(_ k: Int) -> String { k == open.count && decided.isEmpty ? "\(k)" : "\(k) of \(n)" }

    /// "Keep current for 3 · the download is left, as E03 chose, now: nothing else in it to decide".
    public func keepOutcome(_ v: FinishDisposition) -> String? {
        guard !keep.isEmpty else { return nil }
        return "Keep current for \(keep.count) · " + (keepTail(v) ?? "nothing imported, your library file stays")
    }

    /// The outcome lines above the bar: what Import does, then (in a held
    /// scan) what Keep current does; else Keep current, else Skip.
    public func outcome(_ v: FinishDisposition) -> [String] {
        if let impOutcome { return [impOutcome] + (held ? [keepOutcome(v)].compactMap { $0 } : []) }
        return [keepOutcome(v) ?? skipOutcome].compactMap { $0 }
    }

    /// The prominent Import's second line: "imports in place" or "1 of 4 can import".
    public var importSubtitle: String {
        imp.count == open.count && decided.isEmpty ? "imports in place" : "\(of(imp.count)) can import"
    }

    /// "Skip E06" (the Decide menu's and the panel's item).
    public var skipLabel: String { skip.isEmpty ? "Skip" : "Skip \(ManualImportBulk.codeList(skip.map(code)))" }

    private let code: @Sendable (ManualImportRow) -> String

    /// The decide call for one action; nil when it has no row. Keep sends the
    /// pick per download, except over a standing leave (only a leave goes there).
    public func request(_ action: ManualImportDecideAction, pick: FinishDisposition? = nil,
                        mode: ManualImportMode) -> ManualImportDecideRequest? {
        let target: [ManualImportRow]
        switch action {
        case .importFile: target = imp
        case .keepCurrent: target = keep
        case .skip: target = skip
        }
        guard !target.isEmpty else { return nil }
        var picks: [Int: FinishDisposition] = [:]
        if action == .keepCurrent, held, let pick {
            for id in keepDownloads where pick == .leave || !leaveDownloads.contains(id) { picks[id] = pick }
        }
        return ManualImportDecideRequest(rows: target.map { .init(rowId: $0.rowId, action: action) },
                                         dispositions: picks, importMode: action == .importFile ? mode : nil)
    }

    public init(_ ctx: ManualImportBulk.Context, canRemove: Bool = true) {
        let picked = ctx.rows.filter { ctx.selected.contains($0.rowId) }
        let caps = Dictionary(picked.map { ($0.rowId, ManualImportBulk.caps($0, ctx)) }, uniquingKeysWith: { a, _ in a })
        let cap = { (r: ManualImportRow) in caps[r.rowId]! }
        let titled = ctx.multiTitle
        let code: @Sendable (ManualImportRow) -> String = { ManualImportBulk.shortCode($0, titled: titled) }
        let codes = { (rows: [ManualImportRow]) in ManualImportBulk.codeList(rows.map(code)) }
        self.code = code
        n = picked.count
        open = picked.filter { !cap($0).decided }
        decided = picked.filter { cap($0).decided }
        imp = open.filter { cap($0).bulkImp }
        keep = open.filter { cap($0).keep }
        skip = open.filter { cap($0).skip }
        var r = ManualImportBulkCopy.reasons(open: open, skip: skip, cap: cap, codes: codes)
        decidedNote = decided.isEmpty ? nil
            : "\(codes(decided)) \(decided.count == 1 ? "is" : "are") already decided, so nothing changes for \(decided.count == 1 ? "it" : "them")."

        let keepDls = Array(Set(keep.compactMap { ManualImportDecide.downloadId($0, ctx.scan) })).sorted()
        keepDownloads = keepDls
        held = !keepDls.isEmpty || ctx.scan?.isRescue == true
        let leaves = ManualImportBulkCopy.standingLeaves(keepDls, ctx, code: code)
        leaveDownloads = Set(leaves.map(\.download))
        let allLeave = !keepDls.isEmpty && leaves.count == keepDls.count
        leaveRowCode = allLeave ? leaves.first?.code : nil
        if !leaves.isEmpty && !allLeave {
            r.leave = leaves.map { "\($0.code) chose leave for its download, so that download is left." }.joined(separator: " ")
        }
        let proofRows = keep.filter { cap($0).proof }
        let guarded = keep.contains { ($0.held?.detail ?? ctx.scan?.heldDetail)?.releaseBlocklisted == true }
        let pre: FinishDisposition = leaveRowCode != nil || !canRemove ? .leave : !guarded && !proofRows.isEmpty ? .removeBlocklist : .remove
        preferred = pre
        dispositions = keepDls.isEmpty ? [] : ManualImportBulkCopy.dispositions(
            linked: keepDls.contains { ctx.tallies[$0]?.linked == true }, guarded: guarded, canRemove: canRemove,
            proof: proofRows.isEmpty ? nil : ManualImportBulk.proofDetail(proofRows, ctx),
            preferred: pre, leaveRowCode: leaveRowCode)
        if keepDls.isEmpty {
            keepTail = { _ in nil }
        } else {
            keepTail = ManualImportBulkCopy.keepTail(keep: keep, downloads: keepDls, ctx: ctx, leaveRowCode: leaveRowCode)
        }
        impOutcome = imp.isEmpty ? nil : "Import \(imp.count) · \(codes(imp)) \(imp.count == 1 ? "imports" : "import") in place"
        skipOutcome = skip.isEmpty ? nil : "Skip \(skip.count) · nothing is imported for \(codes(skip))"
        lines = picked.map { (row: ManualImportRow) -> Line in
            Line(rowId: row.rowId, code: code(row), text: ManualImportBulkCopy.lineText(row, cap(row), ctx))
        }
        self.reasons = r
    }
}
