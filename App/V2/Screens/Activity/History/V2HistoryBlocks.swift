import SwiftUI
import FusionhaKit

/// History's insight module (mock `insight`): the totals of the loaded
/// stories beside the 14-day sparkline, one ink, today at full strength.
struct V2HistoryInsight: View {
    let total: Int
    let counts: [HistoryStoryType: Int]
    let sparkline: [HistorySparklineDay]
    @Environment(\.pagePalette) private var page
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sparkline.last.map { "Today · \($0.count.formatted()) events" } ?? "\(total.formatted()) events")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            spark.frame(maxWidth: 170)
        }
        .v2CardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }

    /// "12 upgraded · 30 added · 2 failed" over the loaded rows.
    private var summary: String {
        let parts = [(HistoryStoryType.upgraded, "upgraded"), (.added, "added"), (.failed, "failed"), (.grabbed, "grabbed")]
            .compactMap { type, word in (counts[type] ?? 0) > 0 ? "\(counts[type] ?? 0) \(word)" : nil }
        return parts.isEmpty ? "Nothing in the loaded rows" : parts.joined(separator: " · ")
    }

    private var spark: some View {
        let ink = inkOverride ?? .page
        let peak = max(sparkline.map(\.count).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(sparkline.enumerated()), id: \.offset) { index, day in
                UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 1, bottomTrailingRadius: 1,
                                       topTrailingRadius: 3, style: .continuous)
                    .fill(index == sparkline.count - 1 ? ink.fill : ink.fill.opacity(0.38))
                    .frame(height: max(4, 40 * CGFloat(day.count) / CGFloat(peak)))
            }
        }
        .frame(height: 40, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// The raw log's overview (mock `rawStrip`): one count per event kind.
struct V2HistoryRawStrip: View {
    let counts: [String: Int]

    var body: some View {
        HStack {
            ForEach(Array(V2HistoryFilters.rawKinds.enumerated()), id: \.offset) { index, kind in
                if index > 0 { Spacer(minLength: 6) }
                V2KeyFigure(value: (counts[kind.id] ?? 0).formatted(), label: kind.label.lowercased(),
                            tint: kind.id == "failed" && (counts[kind.id] ?? 0) > 0 ? Theme.dangerText : nil)
            }
        }
        .v2CardStyle(padding: 14)
    }
}

/// The two filter rows (stories by kind, raw events by kind).
enum V2HistoryFilters {
    struct Kind {
        let id: String
        let label: String
    }

    static let rawKinds: [Kind] = [
        Kind(id: "grabbed", label: "Grabbed"), Kind(id: "imported", label: "Imported"),
        Kind(id: "deleted", label: "Deleted"), Kind(id: "renamed", label: "Renamed"), Kind(id: "failed", label: "Failed"),
    ]

    static func story(_ counts: [HistoryStoryType: Int], all: Int) -> [V2GlassChips<HistoryStoryType?>.Option] {
        var out: [V2GlassChips<HistoryStoryType?>.Option] = [.init(value: nil, label: "All", count: all)]
        for type in [HistoryStoryType.upgraded, .added, .failed, .grabbed, .deleted] where (counts[type] ?? 0) > 0 {
            out.append(.init(value: type, label: type == .upgraded ? "Upgrades" : type.label, count: counts[type]))
        }
        return out
    }

    static func raw(_ counts: [String: Int], all: Int) -> [V2GlassChips<String?>.Option] {
        var out: [V2GlassChips<String?>.Option] = [.init(value: nil, label: "All", count: all)]
        for kind in rawKinds where (counts[kind.id] ?? 0) > 0 {
            out.append(.init(value: kind.id, label: kind.label, count: counts[kind.id]))
        }
        return out
    }
}
