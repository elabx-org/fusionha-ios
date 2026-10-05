import SwiftUI
import WidgetKit
import FusionhaKit

/// `HD` / `4K` in the tier colour (HD purple, 4K cyan) with a status dot
/// coloured through `EditionStatus.color`, like the calendar's edition rails.
struct WidgetTierPill: View {
    let tier: QualityTier
    var status: EditionStatus?

    var body: some View {
        HStack(spacing: 3) {
            if let status {
                Circle().fill(status.color).frame(width: 5, height: 5)
            }
            Text(tier.pill)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(tier.color)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1.5)
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(tier.color.opacity(0.5), lineWidth: 0.75))
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.chipLabel)\(status.map { ", \($0.label)" } ?? "")")
    }
}

struct WidgetTierPills: View {
    let editions: [(tier: QualityTier, status: EditionStatus?)]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(editions.enumerated()), id: \.offset) { _, edition in
                WidgetTierPill(tier: edition.tier, status: edition.status)
            }
        }
        .fixedSize()
    }
}

extension UpNextItem {
    var pills: [(tier: QualityTier, status: EditionStatus?)] {
        editions.map { (tier: $0.tier, status: $0.status.editionStatus) }
    }
}

extension RecentImport {
    var pills: [(tier: QualityTier, status: EditionStatus?)] {
        tiers.map { (tier: $0, status: EditionStatus.downloaded) }
    }
}
