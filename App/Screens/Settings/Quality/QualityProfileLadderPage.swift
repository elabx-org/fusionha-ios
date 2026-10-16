import SwiftUI
import FusionhaKit

/// The editor's Qualities ladder (web Qualities pane): best at the top, each
/// quality or equal-rank group allowed or not, reordered by dragging or the
/// up / down buttons. "Edit Groups" expands groups to rename, ungroup and move
/// members, and lets any quality join, leave or start a group.
struct QualityProfileLadderPage: View {
    @Bindable var draft: QualityProfileDraft
    @State private var groupEdit = false

    var body: some View {
        Form {
            Section {
                ForEach(Array(draft.rows.enumerated()), id: \.element.id) { index, row in
                    rowView(row, index: index)
                }
                .onMove { draft.moveRows(from: $0, to: $1) }
            } header: {
                Text("\(draft.allowedCount) allowed · Upgrade until \(draft.cutoffLabel)")
            } footer: {
                Text("higher = preferred · drag to reorder")
            }
        }
        .navigationTitle("Qualities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(groupEdit ? "Done" : "Edit Groups") { groupEdit.toggle() }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: QualityLadderRow, index: Int) -> some View {
        switch row {
        case .quality(let q):
            QualityLadderQualityRow(draft: draft, row: row, quality: q, index: index, groupEdit: groupEdit)
        case .group(let g):
            QualityLadderGroupRow(draft: draft, row: row, group: g, index: index, groupEdit: groupEdit)
        }
    }
}

/// One standalone quality in the ladder.
struct QualityLadderQualityRow: View {
    let draft: QualityProfileDraft
    let row: QualityLadderRow
    let quality: QualityLadderQuality
    let index: Int
    let groupEdit: Bool

    var body: some View {
        let label = QualityLadder.label(quality.quality)
        HStack(spacing: 10) {
            QualityLadderMoveButtons(label: label,
                                     up: { draft.moveRow(index, by: -1) },
                                     down: { draft.moveRow(index, by: 1) })
            Toggle(isOn: Binding(get: { quality.allowed }, set: { draft.setAllowed(row, $0) })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label).font(.subheadline.weight(.medium))
                        .foregroundStyle(quality.allowed ? Theme.txt : Theme.dim)
                    if draft.isCutoff(row) { QualityLadderCutoffMark() }
                }
            }
            .tint(Theme.i1)
            .accessibilityLabel("Allow \(label)")
            if groupEdit {
                QualityLadderGroupMenu(draft: draft, quality: quality.quality, currentGroupID: nil)
            }
        }
    }
}

/// The ↑ / ↓ reorder buttons (the web's keyboard path for the drag).
struct QualityLadderMoveButtons: View {
    let label: String
    let up: () -> Void
    let down: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Button(action: up) { Image(systemName: "chevron.up") }
                .accessibilityLabel("Move \(label) up")
            Button(action: down) { Image(systemName: "chevron.down") }
                .accessibilityLabel("Move \(label) down")
        }
        .buttonStyle(.borderless)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.mut)
    }
}

/// The "UPGRADE UNTIL" flag on the cutoff row.
struct QualityLadderCutoffMark: View {
    var body: some View {
        Text("UPGRADE UNTIL")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(Theme.done)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.done.opacity(0.14), in: Capsule())
    }
}
