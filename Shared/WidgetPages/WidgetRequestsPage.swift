import SwiftUI
import WidgetKit
import FusionhaKit

/// Requests & issues, medium and large: the newest requests awaiting approval
/// and the newest open issue as poster rows (medium: two rows; the issue takes
/// the second when there is one). Large leads with Pending / In progress /
/// Issues tiles and shows up to four rows.
struct WidgetRequestsPage: View {
    let data: WidgetPageData
    let large: Bool

    var body: some View {
        if let s = data.requests {
            VStack(alignment: .leading, spacing: 10) {
                if large { tiles(s) }
                if s.newest.isEmpty && s.issue == nil {
                    WidgetStatusMessage(icon: "checkmark.circle.fill", text: "Nothing waiting", tint: Theme.done)
                } else {
                    rows(s)
                }
            }
        } else {
            WidgetStatusMessage(icon: "tray", text: "Requests unavailable")
        }
    }

    private func tiles(_ s: WidgetRequestsSummary) -> some View {
        HStack(spacing: 8) {
            WidgetStatTile(value: "\(s.pending)", label: "Pending", color: Theme.miss)
            WidgetStatTile(value: "\(s.inProgress)", label: "In progress", color: Theme.grab)
            WidgetStatTile(value: "\(s.openIssues)", label: "Issues", color: Theme.danger)
        }
    }

    @ViewBuilder
    private func rows(_ s: WidgetRequestsSummary) -> some View {
        let slots = large ? 4 : 2
        let requests = Array(s.newest.prefix(s.issue == nil ? slots : slots - 1))
        ForEach(Array(requests.enumerated()), id: \.offset) { _, row in
            WidgetRequestLine(row: row, title: data.requestTitles[row.id], poster: data.requestPosters[row.id],
                              requester: row.userId.map { data.userNames[$0] ?? "user #\($0)" })
        }
        if let issue = s.issue { WidgetIssueLine(issue: issue, title: data.issueTitle) }
    }
}
