import SwiftUI
import FusionhaKit

/// The Files segment (mock bulk `fileRows`): every file on one card, rows
/// split by hairlines. A tick (select is not import), the code and title,
/// what it will do and why, and the choice as a monochrome tag ("Decide" in
/// the held ink while it still needs the owner). A tap opens the file.
struct V2MIFilesList: View {
    let open: (Int) -> Void
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store

    var body: some View {
        let rows = session.rows.filter { store.shows($0, session) }
        if rows.isEmpty {
            Text("No files here.").font(.footnote).foregroundStyle(Theme.mut).padding(.top, 8)
        } else {
            ModuleRows {
                ForEach(rows) { V2MIFileRow(row: $0, open: open) }
            }
            .padding(.horizontal, 14)
            .background { ModuleSurface(radius: 18) }
        }
    }
}

struct V2MIFileRow: View {
    let row: ManualImportRow
    let open: (Int) -> Void
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @Environment(\.pagePalette) private var page
    @ScaledMetric(relativeTo: .body) private var tick: CGFloat = 22

    var body: some View {
        let problem = MIProblemGrouping.problem(row)
        let choice = store.choice(row, session)
        let on = session.selected.contains(row.rowId)
        HStack(spacing: 11) {
            Button { session.toggle(row) } label: {
                ZStack {
                    Circle().strokeBorder(Theme.txt.opacity(0.35), lineWidth: 1.5).opacity(on ? 0 : 1)
                    Circle().fill(Theme.primary).opacity(on ? 1 : 0)
                    Image(systemName: "checkmark").font(.system(size: tick * 0.5, weight: .bold))
                        .foregroundStyle(Theme.onAccent).opacity(on ? 1 : 0)
                }
                .frame(width: tick, height: tick)
            }
            .buttonStyle(.plain)
            .disabled(row.committed)
            .opacity(row.committed ? 0.3 : 1)
            .accessibilityLabel(on ? "Ticked" : "Not ticked")
            .accessibilityAddTraits(on ? .isSelected : [])
            Button { open(row.rowId) } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(page?.ink ?? Theme.txt)
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
    }

    /// "E1 · The.Office.S05E01…" (the file name until episode titles reach Manual Import).
    private var title: String {
        let code = ManualImportBulk.shortCode(row)
        return code == row.filename ? code : "\(code) · \(row.filename)"
    }

    private func detail(_ p: MIProblem, _ c: MIChoice?) -> String {
        guard !row.committed else { return "Imported" }
        let doing = c.map { MIProblemCopy.label($0, p, count: 1, row: row) } ?? "Needs a decision"
        return "\(doing) · \(MIProblemCopy.short(p))"
    }
}

/// A file's choice as a tag in the page's ink: Import filled, Keep yours
/// outlined, Skip quiet; an undecided file says Decide in the held ink.
struct MIChoiceTag: View {
    let choice: MIChoice?
    var committed = false

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            }
            .fixedSize()
    }

    private var text: String {
        if committed { return "Imported" }
        switch choice {
        case .importFile?, .assign?: return "Import"
        case .keep?: return "Keep yours"
        case .skip?: return "Skip"
        case .rematch?: return "Re-match"
        case nil: return "Decide"
        }
    }

    private var ink: Color {
        if committed { return Theme.mut }
        switch choice {
        case .importFile?, .assign?: return Theme.bg
        case nil: return Theme.stuckText
        default: return Theme.txt
        }
    }

    private var fill: Color {
        if committed { return .clear }
        switch choice {
        case .importFile?, .assign?: return Theme.txt.opacity(0.88)
        case .skip?: return Theme.txt.opacity(0.08)
        default: return .clear
        }
    }

    private var stroke: Color {
        if committed { return .clear }
        switch choice {
        case .keep?, .rematch?: return Theme.txt.opacity(0.45)
        case nil: return Theme.stuck
        default: return .clear
        }
    }
}
