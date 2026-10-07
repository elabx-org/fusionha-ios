import SwiftUI
import WidgetKit
import FusionhaKit

/// Requests & issues, small: requests awaiting approval, big, and open issues.
struct WidgetRequestsSmall: View {
    let summary: WidgetRequestsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Requests")
            Spacer(minLength: 6)
            WidgetNumber(value: "\(summary.pending)", caption: "awaiting approval", size: 44,
                         tint: summary.pending > 0 ? Theme.miss : .primary)
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 4) {
                WidgetDotLine(color: Theme.grab, text: "\(summary.inProgress) in progress")
                WidgetDotLine(color: Theme.danger,
                              text: "\(summary.openIssues) open issue\(summary.openIssues == 1 ? "" : "s")")
            }
        }
    }
}
