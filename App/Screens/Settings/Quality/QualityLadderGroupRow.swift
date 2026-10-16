import SwiftUI
import FusionhaKit

/// A quality group in the ladder. Collapsed it is one row (name + member
/// tags), since members rank equal; in Edit Groups it shows the name field,
/// Ungroup, and each member with its group menu and reorder buttons.
struct QualityLadderGroupRow: View {
    let draft: QualityProfileDraft
    let row: QualityLadderRow
    let group: QualityLadderGroup
    let index: Int
    let groupEdit: Bool

    var body: some View {
        if groupEdit { expanded } else { collapsed }
    }

    private var allowed: Binding<Bool> {
        Binding(get: { group.allowed }, set: { draft.setAllowed(row, $0) })
    }

    private var moves: some View {
        QualityLadderMoveButtons(label: group.name,
                                 up: { draft.moveRow(index, by: -1) },
                                 down: { draft.moveRow(index, by: 1) })
    }

    private var collapsed: some View {
        HStack(spacing: 10) {
            moves
            Toggle(isOn: allowed) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name).font(.subheadline.weight(.semibold))
                        .foregroundStyle(group.allowed ? Theme.txt : Theme.dim)
                    Text(group.qualities.map(QualityLadder.label).joined(separator: " · "))
                        .font(.caption).foregroundStyle(Theme.mut)
                    if draft.isCutoff(row) { QualityLadderCutoffMark() }
                }
            }
            .tint(Theme.i1)
            .accessibilityLabel("Allow \(group.name)")
        }
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                moves
                Toggle("Allow \(group.name)", isOn: allowed).labelsHidden().tint(Theme.i1)
                TextField("Group name", text: Binding(get: { group.name }, set: { draft.renameGroup(group.id, $0) }))
                    .font(.subheadline.weight(.semibold))
                    .autocorrectionDisabled()
                Text("= equal rank").font(.caption).foregroundStyle(Theme.dim)
                Button(role: .destructive) { draft.dissolve(group.id) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Ungroup \(group.name)")
            }
            if draft.isCutoff(row) { QualityLadderCutoffMark() }
            ForEach(Array(group.qualities.enumerated()), id: \.element) { mi, q in
                member(q, at: mi)
            }
        }
        .padding(.vertical, 4)
    }

    private func member(_ q: String, at mi: Int) -> some View {
        let label = QualityLadder.label(q)
        return HStack(spacing: 10) {
            QualityLadderMoveButtons(label: label,
                                     up: { draft.moveMember(group.id, mi, by: -1) },
                                     down: { draft.moveMember(group.id, mi, by: 1) })
            Text(label).font(.subheadline).foregroundStyle(Theme.txt)
            Spacer(minLength: 0)
            QualityLadderGroupMenu(draft: draft, quality: q, currentGroupID: group.id)
        }
        .padding(.leading, 18)
    }
}

/// Move a quality between "No group", any existing group, or a new group (the
/// accessible equivalent of dragging it in or out).
struct QualityLadderGroupMenu: View {
    let draft: QualityProfileDraft
    let quality: String
    let currentGroupID: String?

    var body: some View {
        Menu {
            Button("No group") { draft.assign(quality, to: .standalone) }
            ForEach(draft.groups, id: \.id) { g in
                Button(g.name) { draft.assign(quality, to: .group(g.id)) }
            }
            Button("New group", systemImage: "plus") { draft.assign(quality, to: .new) }
        } label: {
            HStack(spacing: 3) {
                Text(currentName).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.mut)
        }
        .accessibilityLabel("Group for \(QualityLadder.label(quality))")
    }

    private var currentName: String {
        guard let currentGroupID else { return "No group" }
        return draft.groups.first { $0.id == currentGroupID }?.name ?? "No group"
    }
}
