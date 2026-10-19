import SwiftUI
import FusionhaKit

/// "Mine" (web `MyRequests`): my requests or my issues. The filter sheet
/// picks the type, the status and the sources (one header row, no rails).
struct MineView: View {
    let filter: RequestsFilter.Values

    var body: some View {
        if filter.mineIssues { MyIssuesView() } else {
            MyRequestsView(fixedFilter: filter.mineStatus, origins: filter.origins)
        }
    }
}
