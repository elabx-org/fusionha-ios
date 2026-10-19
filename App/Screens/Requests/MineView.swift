import SwiftUI
import FusionhaKit

/// "Mine" (web `MyRequests`): Requests | Issues, the choice remembered on this phone.
struct MineView: View {
    enum Pane: String, Hashable { case requests, issues }

    /// Inside the approver's Requests the filter sheet picks the type, the
    /// status and the sources (Final: one header row, no in-page rails).
    var filter: RequestsFilter.Values? = nil
    @AppStorage("myRequests.view") private var view: Pane = .requests

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let filter {
                if filter.mineIssues { MyIssuesView() } else {
                    MyRequestsView(fixedFilter: filter.mineStatus, origins: filter.origins)
                }
            } else {
                Picker("Mine", selection: $view) {
                    Text("Requests").tag(Pane.requests)
                    Text("Issues").tag(Pane.issues)
                }
                .pickerStyle(.segmented)
                if view == .issues { MyIssuesView() } else { MyRequestsView() }
            }
        }
    }
}
