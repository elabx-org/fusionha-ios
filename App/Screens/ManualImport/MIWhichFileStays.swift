import SwiftUI
import FusionhaKit

/// "Which file stays?" (the web's `WhichFileStays`): the file on disk and this
/// file side by side; tap the one you want. "This file" is bound to the file
/// on screen; "Current" never expires. A held upgrade shows This file
/// preselected (display only, nothing is sent).
struct MIWhichFileStays: View {
    let row: ManualImportRow
    let pending: Bool
    let onPick: (String) -> Void
    @State private var showAll = false

    private var current: ManualImportExistingFile? { row.existingFile }
    private var worse: Bool { current?.verdict.map { $0.upgrade != true } ?? (row.held != nil) }
    private var selection: String? {
        row.replaceChoice ?? (row.held != nil && current != nil && !worse ? "import" : nil)
    }

    var body: some View {
        let rows = ManualImportCompare.whichFileRows(row) ?? []
        let changed = rows.filter(\.changed)
        VStack(alignment: .leading, spacing: 10) {
            Text("Which file stays?").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
            HStack(spacing: 8) {
                choice("keep_current", icon: "internaldrive", tint: Theme.dim, title: "Current",
                       sub: "\(current?.releaseGroup ?? "on disk") · on disk")
                choice("import", icon: worse ? "arrow.down" : "arrow.up", tint: worse ? Theme.danger : Theme.done,
                       title: "This file", sub: "\(row.parsed.releaseGroup ?? "new") · \(worse ? "downgrade" : "upgrade")")
            }
            if rows.isEmpty {
                Text("Both files are compared once they're measured.").font(.footnote).foregroundStyle(Theme.mut)
            } else {
                MICompareGrid(rows: showAll ? rows : changed)
                if rows.count > changed.count {
                    Button(showAll ? "Show fewer" : "Show all \(rows.count)") { showAll.toggle() }
                        .buttonStyle(ActButtonStyle(kind: .ghost))
                }
            }
            Text(hint).font(.footnote).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
        }
        .sensoryFeedback(.selection, trigger: row.replaceChoice)
    }

    private var hint: String {
        let group = current?.releaseGroup ?? "current"
        switch selection {
        case "import": return worse ? "This file replaces your \(group) file, a downgrade on the rows marked with a down arrow." : "This file replaces your \(group) file."
        case "keep_current": return "Your \(group) file stays. This one is skipped\(row.held != nil ? ", and the download is removed when you finish" : "")."
        default: return "Tap the file you want to keep in your library."
        }
    }

    private func choice(_ value: String, icon: String, tint: Color, title: String, sub: String) -> some View {
        let on = selection == value
        return Button { if !pending, row.replaceChoice != value { onPick(value) } } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundStyle(tint)
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                    Spacer(minLength: 0)
                    Image(systemName: on ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(on ? Theme.i1 : Theme.dim)
                }
                Text(sub).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .strokeBorder(on ? Theme.i1 : Theme.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .opacity(pending ? 0.6 : 1)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Current vs this file, one attribute a line; this file's value carries the direction.
struct MICompareGrid: View {
    let rows: [ManualImportCompare.WhichRow]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
            ForEach(rows, id: \.label) { r in
                GridRow {
                    Text(r.label).foregroundStyle(Theme.mut)
                    Text(r.current).foregroundStyle(Theme.txt)
                    HStack(spacing: 3) {
                        if r.tone != .same {
                            Image(systemName: r.tone == .up ? "arrow.up" : "arrow.down").font(.system(size: 10, weight: .bold))
                        }
                        Text(r.incoming)
                    }
                    .foregroundStyle(r.tone == .up ? Theme.done : r.tone == .down ? Theme.danger : Theme.txt)
                }
                .font(.system(size: 12.5))
            }
        }
    }
}

/// The upgrade compare (no choice to make): the changed attributes only.
struct MICompareTable: View {
    let row: ManualImportRow
    let title: String

    var body: some View {
        if let rows = ManualImportCompare.whichFileRows(row), !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                MICompareGrid(rows: rows.filter(\.changed))
            }
        }
    }
}
