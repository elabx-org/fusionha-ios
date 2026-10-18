import SwiftUI
import FusionhaKit

/// One registered file: selection circle, tier chip, episode code, the file
/// name, its release facts and its health (dead link, unreadable, extra).
struct ManageFileRowView: View {
    let item: ManagedFileItem
    let selecting: Bool
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if selecting {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Theme.i1 : Theme.dim)
                    .contentTransition(.symbolEffect(.replace))
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    DetailTierChip(tier: item.row.tier, short: true)
                    if let ep = item.episodeLabel {
                        Text(ep).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.txt)
                    }
                    health
                    Spacer(minLength: 0)
                }
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(item.extra ? Theme.mut : Theme.txt)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(item.facts.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selecting && selected ? .isSelected : [])
    }

    @ViewBuilder private var health: some View {
        if item.dead {
            tag("Dead link", "link.badge.plus", Theme.danger)
        } else if item.unreadable {
            tag("Unreadable", "exclamationmark.triangle", Theme.miss)
        }
        if item.extra { tag("Extra", "doc.on.doc", Theme.dim) }
        if !item.monitored { tag("Unmonitored", "bookmark", Theme.dim) }
    }

    private func tag(_ text: String, _ symbol: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}
