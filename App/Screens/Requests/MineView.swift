import SwiftUI
import FusionhaKit

/// "Mine" and a requester's "My requests" (web `MyRequests`): the shared
/// header with the subtitle from `mine-header.ts` ("3 open · 6 available",
/// "Nothing open", "Issues you reported"), then my requests or my issues.
/// Show, Source and Type live in the filter sheet (one header row, no rails).
struct MineView: View {
    @Environment(RequestsNav.self) private var nav

    var body: some View {
        let filter = nav.filter[.mine]
        VStack(alignment: .leading, spacing: 14) {
            RequestsViewHeader {
                switch MineHeader.subtitle(nav.mineCounts, issues: filter.mineIssues) {
                case .counts(let open, let available)?:
                    requestsCount(open, "open") + Text(verbatim: " · \(available) available")
                case let subtitle?:
                    Text(subtitle.text)
                case nil:
                    EmptyView()
                }
            }
            if filter.mineIssues {
                MyIssuesView().onAppear { nav.resultLabel = nil }
            } else {
                MyRequestsView(show: filter.mineStatus, source: filter.mineSource)
            }
        }
    }
}
