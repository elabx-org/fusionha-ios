import SwiftUI
import FusionhaKit

/// One file of an opened card (mock `fileCard`): yours against this
/// download (runtime, release, size, score), then its own choices. A
/// choice that costs your copy rings the card in red and names the loss.
struct MIFileCompareCard: View {
    let row: ManualImportRow
    let group: MIGroup
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @Environment(\.pagePalette) private var page

    var body: some View {
        let rows = session.rows
        let chosen = store.choice(row, session)
        let one = MIGroup(problem: group.problem, rows: [row])
        let options = MIProblemGrouping.options(row, rows: rows).map { c -> MIChoiceList.Option in
            let said = MIProblemCopy.consequence(c, one)
            return MIChoiceList.Option(choice: c, title: MIProblemCopy.label(c, group.problem, count: 1, row: row),
                                       detail: said.text, loss: said.loss)
        }
        let losing = options.first { $0.choice == chosen }?.loss == true
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ManualImportBulk.shortCode(row)).font(.system(size: 15, weight: .bold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                if let title = V2MIEpisodeNames.title(row, session) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(page?.ink ?? Theme.txt)
                        .lineLimit(1)
                } else {
                    Text(row.filename).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 0)
                NavigationLink(value: V2MIRoute.file(row.rowId)) {
                    Image(systemName: "info.circle").font(.system(size: 15))
                }
                .accessibilityLabel("File details")
            }
            if V2MIEpisodeNames.title(row, session) != nil {
                Text(row.filename).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(1).truncationMode(.middle)
            }
            MICompareFacts(row: row)
            if let error = session.rowErrors[row.rowId] {
                Text(error).font(.footnote).foregroundStyle(Theme.danger)
            }
            if !options.isEmpty {
                MIChoiceList(options: options, chosen: chosen, pick: MIProblemGrouping.pick(row, rows: rows), dense: true) { c in
                    store.draft.setFile(row, c, rows: rows)
                }
            }
        }
        .padding(12)
        .background { ModuleSurface(radius: 16) }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.danger, lineWidth: 2)
                .opacity(losing ? 1 : 0)
        }
    }
}
