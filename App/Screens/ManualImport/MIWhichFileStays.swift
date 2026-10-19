import SwiftUI
import FusionhaKit

/// "Which file stays?" (the web's `WhichFileStays`, ruling R9: its column
/// pick): the file on disk and this file as two columns; tap a column's head
/// or any of its values to keep that file. "This file" is bound to the file on
/// screen; "Current" never expires. A held upgrade shows This file selected
/// (display only, nothing is sent).
struct MIWhichFileStays: View {
    let row: ManualImportRow
    let pending: Bool
    let onPick: (String) -> Void
    @State private var showAll = false

    private enum Column: String { case keep = "keep_current", take = "import" }

    private var current: ManualImportExistingFile? { row.existingFile }
    private var worse: Bool { current?.verdict.map { $0.upgrade != true } ?? (row.held != nil) }
    private var selection: Column? {
        (row.replaceChoice ?? (row.held != nil && current != nil && !worse ? "import" : nil)).flatMap(Column.init)
    }

    var body: some View {
        let rows = ManualImportCompare.whichFileRows(row) ?? []
        let changed = rows.filter(\.changed)
        let shown = showAll ? rows : changed
        VStack(alignment: .leading, spacing: 8) {
            Text("WHICH FILE STAYS?").font(.system(size: 12, weight: .semibold)).tracking(0.7).foregroundStyle(Theme.dim)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
                GridRow {
                    Color.clear.frame(width: 1, height: 1).gridCellUnsizedAxes([.horizontal, .vertical])
                    head(.keep, last: shown.isEmpty)
                    head(.take, last: shown.isEmpty)
                }
                ForEach(Array(shown.enumerated()), id: \.element.label) { i, r in
                    GridRow {
                        Text(r.label).font(.system(size: 12)).foregroundStyle(Theme.dim)
                            .frame(minWidth: 76, alignment: .leading)
                        cell(.keep, last: i == shown.count - 1) { Text(r.current).foregroundStyle(Theme.txt) }
                        cell(.take, last: i == shown.count - 1) { incoming(r) }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Which file stays?")
            if rows.count > changed.count {
                Button(showAll ? "Show fewer" : "Show all \(rows.count)") { showAll.toggle() }
                    .buttonStyle(ActButtonStyle(kind: .ghost))
            }
            if rows.isEmpty {
                Text("Both files are compared once they're measured.").font(.footnote).foregroundStyle(Theme.mut)
            }
            Text(hint).font(.footnote).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .opacity(pending ? 0.6 : 1)
        .sensoryFeedback(.selection, trigger: row.replaceChoice)
    }

    private var hint: String {
        let group = current?.releaseGroup ?? "current"
        switch selection {
        case .take: return worse ? "This file replaces your \(group) file, a downgrade on the rows marked with a down arrow." : "This file replaces your \(group) file."
        case .keep: return "Your \(group) file stays. This one is skipped\(row.held != nil ? ", and the download is removed when you finish" : "")."
        case nil: return "Tap the file you want to keep in your library."
        }
    }

    /// The selected column's colour: neutral for Current, amber for a downgrade, green for an upgrade.
    private func tint(_ column: Column) -> Color {
        column == .keep ? Theme.txt : worse ? Theme.miss : Theme.done
    }

    private func head(_ column: Column, last: Bool) -> some View {
        let on = selection == column
        let keep = column == .keep
        let shape = UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: last ? 12 : 0,
                                           bottomTrailingRadius: last ? 12 : 0, topTrailingRadius: 12, style: .continuous)
        return Button { pick(column) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: keep ? "internaldrive" : worse ? "arrow.down" : "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(keep ? Theme.dim : worse ? Theme.danger : Theme.done)
                    .frame(width: 24, height: 24)
                    .background((keep ? Theme.dim : worse ? Theme.danger : Theme.done).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .padding(.bottom, 3)
                Text(keep ? "Current" : "This file").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                Text(keep ? "\(current?.releaseGroup ?? "on disk") · on disk"
                          : "\(row.parsed.releaseGroup ?? "new") · \(worse ? "downgrade" : "upgrade")")
                    .font(.system(size: 11)).foregroundStyle(Theme.dim).lineLimit(1)
            }
            .padding(.horizontal, 8).padding(.top, 9).padding(.bottom, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(on ? tint(column).opacity(keep ? 0.07 : 0.12) : .clear, in: shape)
            .overlay(shape.stroke(on ? tint(column) : Theme.line, lineWidth: on ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(keep ? "Current file" : "This file")
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private func cell<Content: View>(_ column: Column, last: Bool, @ViewBuilder content: () -> Content) -> some View {
        let on = selection == column
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: last ? 12 : 0, bottomTrailingRadius: last ? 12 : 0, style: .continuous)
        return content()
            .font(.system(size: 12.5, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? tint(column).opacity(column == .keep ? 0.07 : 0.12) : .clear, in: shape)
            .contentShape(Rectangle())
            .onTapGesture { pick(column) }
            .accessibilityHidden(true)
    }

    @ViewBuilder private func incoming(_ r: ManualImportCompare.WhichRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if r.tone != .same {
                Image(systemName: r.tone == .up ? "arrow.up" : "arrow.down").font(.system(size: 11, weight: .bold))
            }
            Text(r.incoming)
        }
        .foregroundStyle(r.tone == .up ? Theme.done : r.tone == .down ? Theme.miss : Theme.txt)
    }

    private func pick(_ column: Column) {
        guard !pending, row.replaceChoice != column.rawValue else { return }
        onPick(column.rawValue)
    }
}
