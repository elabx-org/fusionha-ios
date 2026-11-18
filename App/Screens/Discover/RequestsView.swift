import SwiftUI

/// Requester "My requests" tab: the Discover page with the Requests tab on.
struct RequestsView: View {
    var body: some View {
        DiscoverView(initialTab: .requests, title: "My requests")
    }
}
