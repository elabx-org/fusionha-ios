import SwiftUI
import WidgetKit
import FusionhaKit

/// Poster, title, `S1·E5 · Today · 9:00 PM`, and the edition pills.
struct WidgetUpNextRow: View {
    let row: UpNextRow
    var posterHeight: CGFloat = 36
    var timeOnly = false

    var body: some View {
        let item = row.item
        WidgetRowLink(url: WidgetLink.item(item.itemId)) {
            HStack(spacing: 8) {
                WidgetPoster(data: row.poster)
                    .frame(width: posterHeight * 2 / 3, height: posterHeight)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(subtitle(item))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                WidgetTierPills(editions: item.pills)
            }
        }
    }

    private func subtitle(_ item: UpNextItem) -> String {
        let when: String
        if timeOnly {
            when = item.hasTime ? CalendarMath.clock(item.airDate) : "All day"
        } else {
            when = WidgetFeeds.whenLabel(item.airDate, hasTime: item.hasTime)
        }
        return "\(item.code) · \(when)"
    }
}

/// The small family's single item: title, code and time, pills.
struct WidgetUpNextHero: View {
    let row: UpNextRow
    var posterWidth: CGFloat

    var body: some View {
        let item = row.item
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            Text(item.episodeTitle.map { "\(item.code) · \($0)" } ?? item.code)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(WidgetFeeds.whenLabel(item.airDate, hasTime: item.hasTime))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.unaired)
                .lineLimit(1)
            WidgetTierPills(editions: item.pills).padding(.top, 2)
        }
    }
}

/// The small family's latest import: optional poster, title, pills, `3h ago`.
struct WidgetRecentHero: View {
    let row: RecentImportRow
    var posterWidth: CGFloat

    var body: some View {
        let item = row.item
        HStack(alignment: .bottom, spacing: 8) {
            if posterWidth > 0 {
                WidgetPoster(data: row.poster, radius: 6)
                    .frame(width: posterWidth, height: posterWidth * 1.5)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(posterWidth > 0 ? 3 : 2)
                if let at = item.importedAt {
                    Text(WidgetFeeds.agoLabel(at) + (item.count > 1 ? " · \(item.count) files" : ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                WidgetTierPills(editions: item.pills).padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }
}
