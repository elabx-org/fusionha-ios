import SwiftUI
import FusionhaKit

/// The You tab's right page in a Spread (the open iPhone Duo): Watchlists &
/// lists while something needs review, else Sign-in methods (the owner's
/// "never empty, the most useful real item").
struct AccountRightPage: View {
    @Environment(AppModel.self) private var model
    @State private var store = WatchlistsStore()

    var body: some View {
        Group {
            if WatchlistsRoute.spreadOpensLists(store.summary) {
                NavigationStack { WatchlistsPage(store: store) }
            } else {
                SignInMethodsSheet(embedded: true)
            }
        }
        .background(Theme.bg)
        .automaticRequestsLoading(store, client: model.client)
    }
}
