import SwiftUI
import FusionhaKit

/// "Mine" (web `MyRequests`): Requests | Issues, the choice remembered on this phone.
struct MineView: View {
    enum Pane: String, Hashable { case requests, issues }

    @AppStorage("myRequests.view") private var view: Pane = .requests

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Mine", selection: $view) {
                Text("Requests").tag(Pane.requests)
                Text("Issues").tag(Pane.issues)
            }
            .pickerStyle(.segmented)
            if view == .issues { MyIssuesView() } else { MyRequestsView() }
        }
    }
}
