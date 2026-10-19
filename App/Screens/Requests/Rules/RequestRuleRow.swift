import SwiftUI
import FusionhaKit

/// One rule (web `RuleRow`), read as the server's sentence: its order number
/// between up and down (a shield for a guard), the label with a Guard or
/// "Watchlists & lists" chip, who it covers, the version ("Every version"),
/// the sources, a guard's roots with their free space, the switch, then how
/// often it fired with Edit and Delete. Status is the ambient wash, never a
/// left accent; an off control says why when tapped.
struct RequestRuleRow: View {
    let rule: RequestRule
    let index: Int
    let count: Int
    let reasons: RuleRowCopy.Reasons
    let roots: [GuardRoot]
    let busy: Bool
    let onToggle: (Bool) -> Void
    let onMove: (Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isGuard: Bool { rule.kind.isGuard }
    private var watchlist: Bool { rule.kind == .watchlistApprove }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                order
                VStack(alignment: .leading, spacing: 6) {
                    title
                    chips
                    if isGuard && !roots.isEmpty { rootsLine }
                }
                .opacity(rule.enabled ? 1 : 0.5)
                Spacer(minLength: 0)
                GatedTip(reason: reasons.toggle) {
                    Toggle("Enable rule: \(rule.label)", isOn: Binding(get: { rule.enabled }, set: onToggle))
                        .labelsHidden().tint(Theme.i1)
                        .disabled(busy)
                }
            }
            HStack(spacing: 4) {
                Text(rule.firedLine).font(.system(size: 12)).foregroundStyle(Theme.mut)
                Spacer(minLength: 4)
                iconButton("pencil", "Edit \"\(rule.label)\"", reason: reasons.edit, action: onEdit)
                iconButton("trash", "Delete \"\(rule.label)\"", reason: reasons.delete, tint: Theme.danger, action: onDelete)
            }
        }
        .padding(10)
        .actWash(rule.enabled ? (isGuard ? Theme.danger : Theme.done) : nil, radius: 12, base: Theme.card)
    }

    @ViewBuilder
    private var order: some View {
        if isGuard {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 15))
                .foregroundStyle(Theme.danger)
                .frame(minWidth: 26)
                .accessibilityHidden(true)
        } else {
            VStack(spacing: 0) {
                iconButton("chevron.up", "Move \"\(rule.label)\" up", reason: reasons.order, off: index == 0, size: 30) { onMove(-1) }
                Text(verbatim: "\(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.dim)
                iconButton("chevron.down", "Move \"\(rule.label)\" down", reason: reasons.order, off: index == count - 1, size: 30) { onMove(1) }
            }
            .frame(minWidth: 26)
        }
    }

    private var title: some View {
        ActFlow(spacing: 6, lineSpacing: 4) {
            Text(rule.label)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
            if isGuard { pill("Guard", tint: Theme.danger) }
            if watchlist {
                Label { Text("Watchlists & lists") } icon: { RequestSourceGlyph(kind: "PLEX_LIST", size: 11) }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.i2)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Theme.i2.opacity(0.12), in: Capsule())
            }
        }
    }

    private var chips: some View {
        ActFlow(spacing: 5, lineSpacing: 5) {
            quiet(RuleRowCopy.audience(rule))
            if let tier = rule.tier { ActTierChip(tier: tier) } else { quiet("Every version") }
            if watchlist { quiet("Sources: \(RuleSource.words(RuleSource.of(rule.params)))") }
        }
    }

    private var rootsLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(roots, id: \.path) { root in
                (Text(root.line.path) + Text(" · ") + Text(root.line.free).fontWeight(.semibold).foregroundColor(Theme.txt))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
            }
        }
    }

    private func pill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private func quiet(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Theme.panel2, in: Capsule())
    }

    private func iconButton(_ symbol: String, _ label: String, reason: String?, off: Bool = false, tint: Color = Theme.txt,
                            size: CGFloat = 44, action: @escaping () -> Void) -> some View {
        GatedTip(reason: reason) {
            Button(action: action) {
                Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).frame(width: 44, height: size)
            }
            .buttonStyle(.plain)
            .foregroundStyle(reason != nil || off ? Theme.dim : tint)
            .disabled(off || busy)
            .accessibilityLabel(label)
        }
    }
}
