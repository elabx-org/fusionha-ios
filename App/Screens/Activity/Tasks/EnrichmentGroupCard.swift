import SwiftUI
import FusionhaKit

/// One reason group (web `EnrichmentGroup`): heading, count, qualifier and the
/// fix-all; opens to what's wrong, how to fix it and each file. Select turns
/// on the checks and a bar of the reason's fixes acting on the checked files.
struct EnrichmentGroupCard: View {
    let group: EnrichmentGroup
    let open: Bool
    let onChanged: () async -> Void
    let onToggle: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @State private var confirm: (fix: EnrichmentFix, ids: [Int])?
    @State private var busy = false
    @State private var selecting = false
    @State private var selected: Set<Int> = []

    private var tone: Color { EnrichmentAttentionView.color(group.tone) }
    /// The checked ids still in the group (a refetch drops stale ones).
    private var selectedIds: [Int] { group.issues.map(\.id).filter { selected.contains($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if open {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.whatsWrong).foregroundStyle(Theme.txt)
                    if !group.howToFix.isEmpty { Text(group.howToFix).foregroundStyle(Theme.mut) }
                }
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
                if selecting { bulkBar }
                ForEach(group.issues) { issue in
                    EnrichmentFileRow(issue: issue, checked: selecting ? selected.contains(issue.id) : nil,
                                      onToggle: { toggle(issue.id) }, onChanged: onChanged)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .actWash(tone, mono: EnrichmentAttentionView.mono(group.tone))
        .disabled(busy)
        .modifier(EnrichmentConfirm(pending: $confirm) { fix, ids, disk in run(fix, ids, disk) })
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(group.heading).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                            Text("\(group.issues.count)").font(.system(size: 12, weight: .bold)).foregroundStyle(tone)
                        }
                        if !group.qualifier.isEmpty {
                            Text(group.qualifier).font(.system(size: 12)).foregroundStyle(Theme.mut)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .trailing, spacing: 6) {
                if let fix = group.fixAll, !selecting {
                    Button("\(group.fixAllLabel) \(group.issues.count)") {
                        let ids = group.issues.map(\.id)
                        if fix == .retry { run(.retry, ids, false) } else { confirm = (fix, ids) }
                    }
                    .buttonStyle(ActButtonStyle(kind: fix == .retry ? .subtle : .warn))
                }
                if !group.fixes.isEmpty {
                    Button(selecting ? "Done" : "Select") { setSelecting(!selecting) }
                        .buttonStyle(ActButtonStyle(kind: .ghost))
                }
            }
        }
    }

    /// "N selected", Select all, and one button per fix the reason offers.
    private var bulkBar: some View {
        let n = selectedIds.count
        let all = n == group.issues.count && n > 0
        return ActFlow(spacing: 8, lineSpacing: 6) {
            Button {
                selected = all ? [] : Set(group.issues.map(\.id))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: all ? "checkmark.circle.fill" : (n > 0 ? "minus.circle.fill" : "circle"))
                        .foregroundStyle(n > 0 ? Theme.accentText : Theme.dim)
                    Text(n > 0 ? "\(n) selected" : "Select all \(group.issues.count)")
                        .foregroundStyle(Theme.txt)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(all ? "Deselect all" : "Select all \(group.issues.count) files in \(group.heading)")
            ForEach(group.fixes, id: \.self) { fix in
                Button {
                    if fix == .retry { run(.retry, selectedIds, false) } else { confirm = (fix, selectedIds) }
                } label: {
                    Label(n > 0 ? "\(fix.label) \(n)" : fix.label, systemImage: fix.symbol)
                }
                .buttonStyle(ActButtonStyle(kind: fix == .retry ? .subtle : (fix == .delete ? .danger : .warn)))
                .disabled(n == 0)
                .opacity(n == 0 ? 0.5 : 1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func setSelecting(_ on: Bool) {
        selecting = on
        selected = []
        if on && !open { onToggle() }
    }

    private func toggle(_ id: Int) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func run(_ fix: EnrichmentFix, _ ids: [Int], _ disk: Bool) {
        confirm = nil
        Task {
            busy = true
            defer { busy = false }
            await EnrichmentActions.run(fix, ids: ids, deleteFromDisk: disk, client: model.client, toaster: toaster)
            selected = []
            await onChanged()
        }
    }
}
