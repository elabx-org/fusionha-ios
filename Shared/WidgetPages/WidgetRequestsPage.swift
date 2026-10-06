import SwiftUI
import WidgetKit
import FusionhaKit

/// Requests & issues, medium and large. Medium: the pending count big beside
/// the newest requests (or the newest issue). Large: pending / in progress /
/// open-issue tiles, the requests awaiting approval and the newest open issue.
struct WidgetRequestsPage: View {
    let data: WidgetPageData
    let large: Bool

    var body: some View {
        if let s = data.requests {
            if large { largeBody(s) } else { mediumBody(s) }
        } else {
            WidgetStatusMessage(icon: "tray", text: "Requests unavailable")
        }
    }

    private func mediumBody(_ s: WidgetRequestsSummary) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetNumber(value: "\(s.pending)", caption: "pending", size: 38, tint: Theme.miss)
                Spacer(minLength: 6)
                WidgetDotLine(color: Theme.danger, text: "\(s.openIssues) open issue\(s.openIssues == 1 ? "" : "s")")
            }
            .frame(width: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: WidgetStyle.rowGap + 4) {
                requests(s, limit: 2)
                if let issue = s.issue, s.newest.count < 2 { WidgetIssueLine(issue: issue, title: data.issueTitle) }
                if s.newest.isEmpty && s.issue == nil { WidgetEmptyText("Nothing waiting") }
            }
        }
    }

    private func largeBody(_ s: WidgetRequestsSummary) -> some View {
        VStack(alignment: .leading, spacing: WidgetStyle.rowGap + 2) {
            HStack(spacing: 8) {
                WidgetStatTile(value: "\(s.pending)", label: "Pending", color: Theme.miss)
                WidgetStatTile(value: "\(s.inProgress)", label: "In progress", color: Theme.grab)
                WidgetStatTile(value: "\(s.openIssues)", label: "Issues", color: Theme.danger)
            }
            if !s.newest.isEmpty { WidgetSectionLabel("Awaiting approval").padding(.top, 4) }
            requests(s, limit: 3)
            if let issue = s.issue {
                WidgetSectionLabel("Newest issue").padding(.top, 4)
                WidgetIssueLine(issue: issue, title: data.issueTitle)
            }
            if s.newest.isEmpty && s.issue == nil {
                WidgetStatusMessage(icon: "checkmark.circle.fill", text: "Nothing waiting", tint: Theme.done)
            }
        }
    }

    private func requests(_ s: WidgetRequestsSummary, limit: Int) -> some View {
        ForEach(Array(s.newest.prefix(limit).enumerated()), id: \.offset) { _, row in
            WidgetRequestLine(row: row, title: data.requestTitles[row.id],
                              requester: row.userId.map { data.userNames[$0] ?? "user #\($0)" })
        }
    }
}
