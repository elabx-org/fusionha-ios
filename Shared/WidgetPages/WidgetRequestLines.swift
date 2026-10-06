import SwiftUI
import WidgetKit
import FusionhaKit

/// A pending request: poster, title, `Requested by Sam · 2h ago`, and the
/// requested tiers.
struct WidgetRequestLine: View {
    let row: WidgetRequestRow
    let title: String?
    let poster: Data?
    let requester: String?

    var body: some View {
        WidgetRowLink(url: WidgetLink.item(row.mediaItemId, fallback: .requests)) {
            WidgetRequestRowLayout(poster: poster, title: title ?? "TMDB #\(row.tmdbId)", subtitle: subtitle,
                                   subtitleColor: .secondary,
                                   pills: row.tiers.map { (tier: $0, status: EditionStatus?.none) })
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let seasons = row.seasons { parts.append(seasons) }
        if let requester { parts.append("Requested by \(requester)") }
        if let at = row.requestedAt.flatMap(CalendarMath.parseUTC) { parts.append(WidgetFeeds.agoLabel(at)) }
        return parts.joined(separator: " · ")
    }
}

/// The newest open issue: `Issue · audio out of sync` in red.
struct WidgetIssueLine: View {
    let issue: WidgetIssueRow
    let title: String?

    var body: some View {
        WidgetRowLink(url: WidgetLink.item(issue.mediaItemId, fallback: .requests)) {
            WidgetRequestRowLayout(poster: nil, title: title ?? "Item #\(issue.mediaItemId)", subtitle: subtitle,
                                   subtitleColor: Theme.danger, pills: [])
        }
    }

    private var subtitle: String {
        var parts = ["Issue"]
        if let text = issue.description, !text.isEmpty { parts.append(text) } else { parts.append(issue.label) }
        return parts.joined(separator: " · ")
    }
}

/// Poster, title over subtitle, chips on the right: the Requests rows' shape.
struct WidgetRequestRowLayout: View {
    let poster: Data?
    let title: String
    let subtitle: String
    let subtitleColor: Color
    let pills: [(tier: QualityTier, status: EditionStatus?)]

    var body: some View {
        HStack(spacing: 12) {
            WidgetPoster(data: poster, radius: WidgetStyle.posterRadius)
                .frame(width: 32, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(WidgetStyle.rowTitle).lineLimit(1)
                Text(subtitle).font(WidgetStyle.caption).foregroundStyle(subtitleColor).lineLimit(1)
            }
            Spacer(minLength: 6)
            WidgetTierPills(editions: pills)
        }
    }
}
