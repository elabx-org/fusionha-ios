import SwiftUI
import FusionhaKit

/// One decided request on v2's History (approved mock `rq-history`): poster,
/// title, "Approved by eafx · 23:18" (or declined by, or asked by), and the
/// status pill on the right. Its versions' media badges sit before the line.
struct V2HistoryRow: View {
    let request: MediaRequest

    var body: some View {
        RequestsListRow(request: request, compact: false) {
            HStack(spacing: 6) {
                RequestTierBadges(request: request)
                Text(line).lineLimit(1)
            }
        } trailing: {
            V2RequestStatusPill(status: request.status)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the conversation")
    }

    /// "Approved by eafx · 23:18": who decided (or who asked), then the time.
    private var line: String {
        var who: String?
        if let by = request.approvedBy {
            who = by.kind == "auto" ? RequestLifecycle.autoText(by) : "Approved by \(by.displayName ?? "an admin")"
        } else if let by = request.declinedBy {
            who = "Declined by \(by.displayName)"
        } else if let asker = request.requester?.displayName {
            who = "Asked by \(asker)"
        }
        let time = RequestHistoryDays.time(RequestHistoryDays.instant(request))
        return [who, time].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
