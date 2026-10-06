import SwiftUI
import WidgetKit
import FusionhaKit

/// Requests & issues: pending, in progress and open-issue counts, the newest
/// pending requests and the newest open issue.
struct WidgetRequestsPage: View {
    let data: WidgetPageData
    let large: Bool

    var body: some View {
        if let s = data.requests {
            VStack(alignment: .leading, spacing: large ? 8 : 5) {
                HStack(spacing: 6) {
                    WidgetStatTile(value: "\(s.pending)", label: "Pending", color: Theme.miss)
                    WidgetStatTile(value: "\(s.inProgress)", label: "In progress", color: Theme.grab)
                    WidgetStatTile(value: "\(s.openIssues)", label: "Open issues", color: Theme.danger)
                }
                if large && !s.newest.isEmpty { WidgetSectionLabel("Awaiting approval") }
                ForEach(Array(s.newest.prefix(rowLimit(s)).enumerated()), id: \.offset) { _, row in
                    WidgetRequestLine(row: row, title: data.requestTitles[row.id],
                                      requester: row.userId.map { data.userNames[$0] ?? "user #\($0)" })
                }
                if let issue = s.issue {
                    if large { WidgetSectionLabel("Newest issue") }
                    WidgetIssueLine(issue: issue, title: data.issueTitle)
                }
                if s.newest.isEmpty && s.issue == nil { WidgetEmptyText("Nothing waiting") }
            }
        } else {
            WidgetEmptyText("Requests unavailable")
        }
    }

    /// Medium shows two requests when there is no open issue.
    private func rowLimit(_ s: WidgetRequestsSummary) -> Int {
        large ? 3 : (s.issue == nil ? 2 : 1)
    }
}

struct WidgetRequestLine: View {
    let row: WidgetRequestRow
    let title: String?
    let requester: String?

    var body: some View {
        WidgetRowLink(url: WidgetLink.item(row.mediaItemId, fallback: .requests)) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title ?? "TMDB #\(row.tmdbId)").font(.caption.weight(.semibold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
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
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title ?? "Item #\(issue.mediaItemId)").font(.caption.weight(.semibold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
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
