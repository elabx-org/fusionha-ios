import SwiftUI
import FusionhaKit

/// One file of the Files segment: a tick (select is not import; drag down
/// the ticks to tick a run), "E1 · Weight Loss" (the file name until the
/// episode titles load, or for a movie), what it will do and why, and the
/// choice as a tag. `cursor` rings the row the j/k keys are on.
struct V2MIFileRow: View {
    let row: ManualImportRow
    var cursor = false
    let open: (Int) -> Void
    /// A drag from this row's tick reached `y` (the list's space); ended.
    var sweep: (Int, Double) -> Void = { _, _ in }
    var sweepEnded: () -> Void = {}
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @Environment(\.pagePalette) private var page
    @ScaledMetric(relativeTo: .body) private var tick: CGFloat = 22

    var body: some View {
        let problem = MIProblemGrouping.problem(row)
        let choice = store.choice(row, session)
        HStack(spacing: 11) {
            tickButton
            Button { open(row.rowId) } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(V2MIEpisodeNames.rowTitle(row, session))
                            .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(page?.ink ?? Theme.txt)
                        Text(detail(problem, choice)).font(.system(size: 12)).foregroundStyle(page?.inkMuted ?? Theme.mut)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    MIChoiceTag(choice: choice, committed: row.committed)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the file")
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.primary, lineWidth: 2)
                .padding(-6)
                .opacity(cursor ? 1 : 0)
                .accessibilityHidden(true)
        }
    }

    private var tickButton: some View {
        let on = session.selected.contains(row.rowId)
        return Button { session.toggle(row) } label: {
            ZStack {
                Circle().strokeBorder(Theme.txt.opacity(0.35), lineWidth: 1.5).opacity(on ? 0 : 1)
                Circle().fill(Theme.primary).opacity(on ? 1 : 0)
                Image(systemName: "checkmark").font(.system(size: tick * 0.5, weight: .bold))
                    .foregroundStyle(Theme.onAccent).opacity(on ? 1 : 0)
            }
            .frame(width: tick, height: tick)
            .padding(.vertical, 6)
            .padding(.trailing, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Down the tick column: tick (or untick) every row passed.
        .highPriorityGesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named(V2MIFilesList.space))
                .onChanged { sweep(row.rowId, Double($0.location.y)) }
                .onEnded { _ in sweepEnded() }
        )
        .disabled(row.committed)
        .opacity(row.committed ? 0.3 : 1)
        .accessibilityLabel(on ? "Ticked" : "Not ticked")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func detail(_ p: MIProblem, _ c: MIChoice?) -> String {
        guard !row.committed else { return "Imported" }
        let doing = c.map { MIProblemCopy.label($0, p, count: 1, row: row) } ?? "Needs a decision"
        return "\(doing) · \(MIProblemCopy.short(p))"
    }
}

/// Episode titles in Manual Import's rows, from the seasons the session
/// loads for every matched series (`ManualImportSession.loadSeasons`).
enum V2MIEpisodeNames {
    /// The first covered episode's title ("Weight Loss + 1 more"), or nil
    /// for a movie, an unmatched file, or before the seasons load.
    static func title(_ row: ManualImportRow, _ session: ManualImportSession) -> String? {
        let titles = MIRowTitle.episodeTitles(row, session)
        guard let first = titles.first else { return nil }
        return titles.count > 1 ? "\(first) + \(titles.count - 1) more" : first
    }

    /// "E1 · Weight Loss", else "E1 · The.Office.S05E01…".
    static func rowTitle(_ row: ManualImportRow, _ session: ManualImportSession) -> String {
        let code = ManualImportBulk.shortCode(row)
        if let title = title(row, session) { return "\(code) · \(title)" }
        return code == row.filename ? code : "\(code) · \(row.filename)"
    }

    /// A card's files: "E1 Weight Loss · E13 Stress Relief" for up to three
    /// titled episodes, else the codes (`MIProblemCopy.files`).
    static func files(_ rows: [ManualImportRow], _ session: ManualImportSession) -> String {
        guard rows.count <= 3 else { return MIProblemCopy.files(rows) }
        let named = rows.compactMap { row in title(row, session).map { "\(ManualImportBulk.shortCode(row)) \($0)" } }
        return named.count == rows.count && !named.isEmpty ? named.joined(separator: " · ") : MIProblemCopy.files(rows)
    }
}
