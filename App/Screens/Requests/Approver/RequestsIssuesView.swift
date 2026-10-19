import SwiftUI
import FusionhaKit

/// Requests › Issues (Proposal 2, approved 2026-10-19): the issue threads
/// under the shared header ("4 open · 2 need you"), with Open · Resolved ·
/// All in the filter sheet. Issues keep their own words (Checking, Fixing,
/// Needs an admin) and their own pane.
struct RequestsIssuesView: View {
    @Environment(RequestsNav.self) private var nav
    @Environment(DiscoverStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RequestsViewHeader {
                requestsCount(store.issueCounts.open, "open")
                    + (store.issueCounts.needYou > 0 ? Text(" · ") + requestsCount(store.issueCounts.needYou, "need you") : Text(""))
            }
            ThreadsPanelView(only: "issue", state: nav.filter[.issues].issueState) { items in
                nav.resultCount = items.count
            }
        }
    }
}
