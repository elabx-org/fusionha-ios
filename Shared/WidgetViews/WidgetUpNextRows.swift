import SwiftUI
import WidgetKit
import FusionhaKit

/// A list row: poster, title, `S1·E5 · Today · 9:00 PM`, and the edition pills.
struct WidgetUpNextRow: View {
    let row: UpNextRow
    var posterHeight: CGFloat = WidgetStyle.rowPoster

    var body: some View {
        let item = row.item
        WidgetRowLink(url: WidgetLink.item(item.itemId)) {
            HStack(spacing: 10) {
                WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                    .frame(width: posterHeight * 2 / 3, height: posterHeight)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(WidgetStyle.title).lineLimit(1)
                    Text("\(item.code) · \(WidgetFeeds.whenLabel(item.airDate, hasTime: item.hasTime))")
                        .font(WidgetStyle.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                WidgetTierPills(editions: item.pills)
            }
        }
    }
}

/// When the next item airs, big: `TODAY` over `9:00` `PM` (or `All day`).
struct WidgetAirTime: View {
    let item: UpNextItem
    var size: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetSectionLabel(WidgetFeeds.whenLabel(item.airDate, hasTime: false), tint: Theme.unaired)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(item.clockParts.time).font(WidgetStyle.numeral(size)).lineLimit(1).minimumScaleFactor(0.7)
                if let period = item.clockParts.period {
                    Text(period).font(WidgetStyle.label).foregroundStyle(.secondary)
                }
            }
            .widgetAccentable()
        }
    }
}

/// The next item as a hero: poster, air time, title, code and pills. Used
/// by the medium and large Up next (the small one stacks it vertically).
struct WidgetUpNextHero: View {
    let row: UpNextRow
    var posterHeight: CGFloat = 81

    var body: some View {
        let item = row.item
        WidgetRowLink(url: WidgetLink.item(item.itemId)) {
            HStack(alignment: .top, spacing: 12) {
                WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                    .frame(width: posterHeight * 2 / 3, height: posterHeight)
                VStack(alignment: .leading, spacing: 3) {
                    WidgetAirTime(item: item, size: 24)
                    Spacer(minLength: 0)
                    Text(item.title).font(WidgetStyle.heroTitle).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.episodeTitle.map { "\(item.code) · \($0)" } ?? item.code)
                            .font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 4)
                        WidgetTierPills(editions: item.pills)
                    }
                }
            }
            .frame(height: posterHeight)
        }
    }
}

extension UpNextItem {
    /// `9:00` and `PM`; `All day` with no period for a date-only release.
    var clockParts: (time: String, period: String?) {
        guard hasTime else { return ("All day", nil) }
        let parts = CalendarMath.clock(airDate).split(separator: " ")
        return (String(parts.first ?? ""), parts.count > 1 ? String(parts[1]) : nil)
    }
}
