import SwiftUI
import FusionhaKit

/// Account on the open iPhone Duo in a Spread (the shell's two-page cover):
/// Account on the left page, and the right page a stack of its own holding
/// Watchlists & lists while something needs review, else Sign-in methods
/// (`WatchlistsRoute.spreadOpensLists`, never empty). The Automatic requests
/// row and a `fusionha://account/lists` link open Watchlists & lists there,
/// and a source pushes its detail inside that stack. The pages come from the
/// cover's own full frame, which content never resizes; without room for two
/// pages it is the single Account stack.
struct AccountSpreadSheet: View {
    @State private var size: CGSize = .zero
    @State private var pages: SpreadGeometry.Pages?
    /// What the Automatic requests row (or a link) asked the right page for.
    @State private var lists: ListsLink?
    /// A new value resets the right page's stack.
    @State private var rightKey = 0

    var body: some View {
        Group {
            if size == .zero {
                Color.clear
            } else if let pages {
                ZStack(alignment: .topLeading) {
                    AccountSheet(onPages: true, openListsOnPage: open)
                        .frame(width: CGFloat(pages.left.width))
                    AccountSpreadRightPage(lists: lists)
                        .id(rightKey)
                        .frame(width: CGFloat(pages.right.width))
                        .offset(x: CGFloat(pages.right.x))
                }
            } else {
                AccountSheet(onPages: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg.ignoresSafeArea())
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onGeometryChange(for: SpreadGeometry.Pages?.self) { proxy in
            proxy.duoPages
        } action: { pages = $0 }
    }

    private func open(_ sourceId: String?) {
        lists = ListsLink(sourceId: sourceId)
        rightKey += 1
    }
}

/// The Spread Account's right page: its own stack and store.
private struct AccountSpreadRightPage: View {
    @Environment(AppModel.self) private var model
    let lists: ListsLink?
    @State private var store = WatchlistsStore()

    var body: some View {
        Group {
            if lists != nil || WatchlistsRoute.spreadOpensLists(store.summary) {
                NavigationStack { WatchlistsPage(store: store, initialSource: lists?.sourceId) }
            } else if store.summary == nil && !store.summaryFailed {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Its own stack, as on the You tab's right page.
                SignInMethodsSheet(embedded: true)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .automaticRequestsLoading(store, client: model.client)
    }
}
