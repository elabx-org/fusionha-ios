import SwiftUI
import FusionhaKit

/// One problem: its badge and title, the sentence, the files, then its
/// choices with Fusionha's pick where the server gives one, or "Mixed" when
/// its files were set one by one.
struct MIGroupCard: View {
    let group: MIGroup
    var lean = false
    var selected = false
    let open: () -> Void
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @Environment(\.pagePalette) private var page

    var body: some View {
        let rows = session.rows
        VStack(alignment: .leading, spacing: 0) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        MIProblemBadge(problem: group.problem)
                        Text(MIProblemCopy.title(group.problem, count: group.rows.count))
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundStyle(page?.ink ?? Theme.txt)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.dim)
                    }
                    if !lean, let why = MIProblemCopy.why(group) {
                        (Text(why.lead).fontWeight(.semibold).foregroundColor(page?.ink ?? Theme.txt)
                            + Text(why.lead.isEmpty ? why.rest : " " + why.rest))
                            .font(.system(size: 13))
                            .foregroundStyle(muted)
                            .padding(.top, 6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(V2MIEpisodeNames.files(group.rows, session))
                        .font(.system(size: 12))
                        .foregroundStyle(muted)
                        .padding(.top, 4)
                        .lineLimit(2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows each file")
            choices(rows)
        }
        .padding(12)
        .background { ModuleSurface(radius: 18, selected: selected) }
    }

    private var muted: Color { page?.inkMuted ?? Theme.mut }

    @ViewBuilder private func choices(_ rows: [ManualImportRow]) -> some View {
        let options = MIProblemGrouping.groupOptions(group, rows: rows)
        switch store.draft.state(group, rows: rows) {
        case .mixed(let overridden):
            MIMixedLine(group: group, overridden: overridden).padding(.top, 10)
        case .uniform(let chosen):
            if !options.isEmpty {
                MIChoiceList(options: options.map { c -> MIChoiceList.Option in
                    let said = MIProblemCopy.consequence(c, group)
                    return MIChoiceList.Option(choice: c, title: MIProblemCopy.label(c, group.problem, count: group.rows.count, row: group.rows.first),
                                 detail: said.text, loss: said.loss)
                }, chosen: chosen, pick: MIProblemGrouping.groupPick(group, rows: rows), dense: lean) { c in
                    store.draft.setGroup(group.problem, c)
                }
                .padding(.top, 8)
            }
        }
    }
}

/// "⇄ Mixed · E13 set on its own": the card's files were changed one by one.
struct MIMixedLine: View {
    let group: MIGroup
    let overridden: [Int]
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "arrow.left.arrow.right").foregroundStyle(Theme.stuckText)
            (Text("Mixed").fontWeight(.semibold).foregroundColor(Theme.stuckText) + Text(" · " + detail))
                .foregroundStyle(Theme.mut)
        }
        .font(.system(size: 12.5))
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let rows = group.rows.filter { overridden.contains($0.rowId) }
        guard !rows.isEmpty else { return "the files differ; open the group to see each" }
        let codes = ManualImportBulk.codeList(rows.prefix(3).map { ManualImportBulk.shortCode($0) })
        let more = rows.count > 3 ? " and \(rows.count - 3) more" : ""
        return "\(codes)\(more) set on \(rows.count == 1 ? "its own" : "their own")"
    }
}

/// The problem's round badge: one ink per problem kind, monochrome glyphs.
struct MIProblemBadge: View {
    let problem: MIProblem

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(ink)
            .frame(width: 28, height: 28)
            .background(fill, in: Circle())
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch problem {
        case .upgrade: return "arrow.up"
        case .new: return "plus"
        case .shorter, .notUpgrade, .mislabeled, .needsLook: return "exclamationmark"
        case .otherEpisode: return "arrow.uturn.right"
        case .twoEpisodes: return "rectangle.split.2x1"
        case .sharedFile: return "link"
        case .noMatch: return "questionmark"
        case .inLibrary, .imported: return "checkmark"
        }
    }

    /// Orange only where the owner's call is needed (a file would cost a
    /// copy, or can't import yet); everything else stays in the page's ink.
    private var needsOwner: Bool {
        [.shorter, .notUpgrade, .mislabeled, .otherEpisode, .needsLook, .noMatch].contains(problem)
    }

    private var fill: Color { needsOwner ? Theme.stuck : Theme.txt.opacity(problem == .imported || problem == .inLibrary ? 0.18 : 0.85) }
    private var ink: Color { needsOwner ? Theme.onFill(hex: Theme.palette.stuck) : problem == .imported || problem == .inLibrary ? Theme.txt : Theme.bg }
}
