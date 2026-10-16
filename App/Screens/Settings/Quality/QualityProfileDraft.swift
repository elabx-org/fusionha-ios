import SwiftUI
import FusionhaKit

/// The quality-profile editor's working state (web `ProfileEditor`): the typed
/// fields, the ladder (rows + Upgrade Until), and the per-format scores with
/// their override baseline. Shared by the editor sheet and its pushed pages.
@MainActor
@Observable
final class QualityProfileDraft {
    let original: QualityProfileRecord?
    var fields: QualityProfileFields
    private(set) var ladder: QualityLadderModel
    /// Score text per custom format id, as typed.
    private(set) var scores: [Int: String]
    /// Formats whose override the user handed back to the source.
    private(set) var released: Set<Int> = []
    let baseline: [Int: QualityProfileScoreBaseline]
    var formats: [QualityProfileFormatOption] = []

    init(_ profile: QualityProfileRecord?) {
        original = profile
        fields = QualityProfileFields(profile)
        var model = profile.map(QualityLadder.seed) ?? QualityLadder.defaultModel()
        model.cutoff = QualityLadder.repairedCutoff(model)
        ladder = model
        var map: [Int: String] = [:]
        for s in profile?.formatScores ?? [] { map[s.customFormatId] = String(s.score) }
        scores = map
        baseline = QualityProfileBody.baseline(profile)
    }

    // MARK: Ladder

    var rows: [QualityLadderRow] { ladder.rows }
    var groups: [QualityLadderGroup] { ladder.rows.compactMap(\.group) }
    var allowedCount: Int { QualityLadder.flatAllowed(ladder.rows).count }
    var cutoffLabel: String { QualityLadder.cutoffLabel(ladder) }
    var cutoffOptions: [(tag: String, label: String)] { QualityLadder.cutoffOptions(ladder.rows) }
    var valid: Bool { !fields.name.trimmingCharacters(in: .whitespaces).isEmpty && allowedCount > 0 }

    /// Every ladder change goes through here so the cutoff stays valid.
    func setRows(_ rows: [QualityLadderRow], cutoff: QualityCutoffSelection? = nil) {
        var next = QualityLadderModel(rows: rows, cutoff: cutoff ?? ladder.cutoff)
        next.cutoff = QualityLadder.repairedCutoff(next)
        ladder = next
    }

    var cutoffTag: String {
        get { ladder.cutoff.tag }
        set { setRows(ladder.rows, cutoff: QualityCutoffSelection.fromTag(newValue)) }
    }

    func isCutoff(_ row: QualityLadderRow) -> Bool {
        switch (row, ladder.cutoff) {
        case (.quality(let q), .quality(let c)): return q.quality == c
        case (.group(let g), .group(let id, _)): return g.id == id
        default: return false
        }
    }

    func setAllowed(_ row: QualityLadderRow, _ on: Bool) {
        setRows(QualityLadder.setAllowed(ladder.rows, rowID: row.id, on))
    }

    func renameGroup(_ id: String, _ name: String) {
        setRows(QualityLadder.renameGroup(ladder.rows, id: id, name))
    }

    func moveRow(_ index: Int, by delta: Int) {
        setRows(QualityLadder.moveRow(ladder.rows, at: index, by: delta))
    }

    func moveRows(from source: IndexSet, to destination: Int) {
        var next = ladder.rows
        next.move(fromOffsets: source, toOffset: destination)
        setRows(next)
    }

    func moveMember(_ groupID: String, _ index: Int, by delta: Int) {
        setRows(QualityLadder.moveMember(ladder.rows, groupID: groupID, at: index, by: delta))
    }

    func dissolve(_ groupID: String) {
        setRows(QualityLadder.dissolve(ladder.rows, id: groupID))
    }

    /// Group / ungroup a quality. Moving the cutoff quality into a group makes
    /// the group the cutoff, carrying the quality as its stored member.
    func assign(_ quality: String, to target: QualityLadder.GroupTarget) {
        let result = QualityLadder.assign(ladder.rows, quality, to: target)
        var cutoff: QualityCutoffSelection?
        if let id = result.groupID, ladder.cutoff == .quality(quality) {
            cutoff = .group(id: id, quality: quality)
        }
        setRows(result.rows, cutoff: cutoff)
    }

    // MARK: Custom formats

    /// This kind's formats plus kindless ones; a legacy kindless profile sees all.
    var kindFormats: [QualityProfileFormatOption] {
        guard let kind = fields.mediaKind else { return formats }
        return formats.filter { $0.mediaKind == nil || $0.mediaKind == kind }
    }

    func live(_ id: Int) -> Int { QualityProfileBody.number(scores[id]) }

    func scoreText(_ id: Int) -> String { scores[id] ?? "0" }

    /// A fresh edit re-asserts ownership.
    func setScore(_ id: Int, _ text: String) {
        scores[id] = text
        released.remove(id)
    }

    func release(_ id: Int) { released.insert(id) }

    func isOverride(_ id: Int) -> Bool {
        QualityProfileBody.isOverride(id, live: live(id), baseline: baseline, released: released)
    }

    var scoredCount: Int { QualityProfileBody.scoredCount(scores: scores, formatIDs: formats.map(\.id)) }

    /// Sorted by the current score (desc), then name: the list re-sorts as you edit.
    func shownFormats(query: String, scoredOnly: Bool) -> [QualityProfileFormatOption] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list: [QualityProfileFormatOption]
        if !needle.isEmpty {
            list = kindFormats.filter { $0.name.lowercased().contains(needle) }
        } else if scoredOnly {
            list = kindFormats.filter { live($0.id) != 0 }
        } else {
            list = kindFormats
        }
        return list.sorted { a, b in
            let la = live(a.id), lb = live(b.id)
            return la != lb ? la > lb : a.name.localizedCompare(b.name) == .orderedAscending
        }
    }

    // MARK: Save

    func body() -> [String: SettingsJSON] {
        let scored = QualityProfileBody.formatScores(scores: scores, formatIDs: formats.map(\.id),
                                                     baseline: baseline, released: released)
        let common = QualityProfileBody.common(fields, formatScores: scored)
        return QualityProfileBody.save(fields: common, model: ladder, original: original)
    }
}
