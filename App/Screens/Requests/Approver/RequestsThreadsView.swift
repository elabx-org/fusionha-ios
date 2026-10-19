import SwiftUI
import FusionhaKit

/// Threads (web `RequestsThreads`): the shared header ("N unread · M open";
/// Type and State live in its sheet) over the thread list. The sheet's button
/// counts the threads the filters leave ("Show 50+ threads" while more load).
struct RequestsThreadsView: View {
    @Environment(RequestsNav.self) private var nav

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RequestsViewHeader {
                requestsCount(nav.unreadThreads, "unread") + Text(verbatim: " · \(nav.openThreads) open")
            }
            ThreadsPanelView(state: nav.filter[.threads].issueState,
                             type: nav.threadTypes ? nav.filter[.threads].threadType : nil) { items, more in
                nav.resultLabel = RequestsResultLabel.text(nil, loaded: items.count, more: more, noun: ("thread", "threads"))
            }
        }
    }
}

/// Requests › Issues (Proposal 2; web `RequestsIssues`): the issue threads
/// under the shared header ("4 open · 2 need you"), with the problem Type and
/// Open · Resolved · All in the filter sheet. Issues keep their own words
/// (Checking, Fixing, Needs an admin) and their own pane.
struct RequestsIssuesView: View {
    @Environment(RequestsNav.self) private var nav
    @Environment(DiscoverStore.self) private var store

    var body: some View {
        let problem = nav.filter[.issues].problem
        VStack(alignment: .leading, spacing: 14) {
            RequestsViewHeader {
                requestsCount(store.issueCounts.open, "open") + Text(" · ") + requestsCount(store.issueCounts.needYou, "need you")
            }
            ThreadsPanelView(only: "issue", state: nav.filter[.issues].issueState,
                             match: problem == "all" ? nil : { IssueProblemFilter.matches($0, problem: problem) }) { items, more in
                nav.resultLabel = RequestsResultLabel.text(nil, loaded: items.count, more: more, noun: ("issue", "issues"))
            }
        }
    }
}
