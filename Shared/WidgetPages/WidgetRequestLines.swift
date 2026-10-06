import SwiftUI
import WidgetKit
import FusionhaKit

/// A pending request: its title, `S1–3 · alice · 2h ago`, and the requested tiers.
struct WidgetRequestLine: View {
    let row: WidgetRequestRow
    let title: String?
    let requester: String?

    var body: some View {
        WidgetRowLink(url: WidgetLink.item(row.mediaItemId, fallback: .requests)) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? "TMDB #\(row.tmdbId)").font(WidgetStyle.title).lineLimit(1)
                    Text(subtitle).font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                WidgetTierPills(editions: row.tiers.map { (tier: $0, status: EditionStatus?.none) })
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let seasons = row.seasons { parts.append(seasons) }
        if let requester { parts.append(requester) }
        if let at = row.requestedAt.flatMap(CalendarMath.parseUTC) { parts.append(WidgetFeeds.agoLabel(at)) }
        return parts.joined(separator: " · ")
    }
}

struct WidgetIssueLine: View {
    let issue: WidgetIssueRow
    let title: String?

    var body: some View {
        WidgetRowLink(url: WidgetLink.item(issue.mediaItemId, fallback: .requests)) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.danger)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? "Item #\(issue.mediaItemId)").font(WidgetStyle.title).lineLimit(1)
                    Text(subtitle).font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var subtitle: String {
        var parts = [issue.label]
        if let at = issue.createdAt.flatMap(CalendarMath.parseUTC) { parts.append(WidgetFeeds.agoLabel(at)) }
        if let text = issue.description, !text.isEmpty { parts.append(text) }
        return parts.joined(separator: " · ")
    }
}
