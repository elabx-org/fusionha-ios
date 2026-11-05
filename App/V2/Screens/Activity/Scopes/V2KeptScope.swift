import SwiftUI

/// A v1 Activity tab kept as it is in v2 (Audit, Indexers: plan S10 "tokens
/// only"): its rows are v1's, on v2's tint ground, with v2's caption and
/// glass scope chips in place of v1's header, and the title search as the
/// bar's pull-down field.
struct V2KeptScope<Content: View>: View {
    let caption: String
    var searchable = false
    @ViewBuilder var content: () -> Content
    @Environment(ActChrome.self) private var chrome

    var body: some View {
        let header = ActivityPageHeaderOverride { [caption] in AnyView(V2KeptScopeHeader(caption: caption)) }
        page(content().environment(\.activityPageHeader, header))
            .v2PageGround(art: nil)
    }

    @ViewBuilder
    private func page(_ view: some View) -> some View {
        @Bindable var chrome = chrome
        if searchable {
            view.searchable(text: $chrome.searchInput, placement: .navigationBarDrawer(displayMode: .automatic),
                            prompt: "Search titles")
        } else {
            view
        }
    }
}

/// The kept tab's header: its caption, then the scopes.
private struct V2KeptScopeHeader: View {
    let caption: String
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            V2ScopeCaption(lead: nil, rest: [caption])
                .font(.system(size: 13))
            V2ActivityScopes(queueCount: model.queueTotal)
        }
        .padding(.bottom, 20)
    }
}
