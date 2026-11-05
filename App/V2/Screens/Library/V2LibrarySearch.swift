import SwiftUI

/// The v2 Library's filter (v2 header): the system's pull-down search field
/// in the navigation bar's drawer, out of sight until the page is pulled
/// down, bound to `model.searchText` as the old on-page field was, so the
/// Search tab's "This library" (`handToLibrary`) still filters the grid.
/// Its scopes keep the old field's switch: Everything hands the words to the
/// Search tab.
struct V2LibrarySearch: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content
            .searchable(text: text, placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Filter the library")
            .searchScopes(scope, activation: .onSearchPresentation) {
                if !model.requestScoped {
                    Text("This library").tag(SearchScope.library)
                    Text("Everything").tag(SearchScope.everything)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }

    private var text: Binding<String> {
        Binding(get: { model.searchText }, set: { model.searchText = $0 })
    }

    /// Always "This library" here; picking Everything goes to the Search tab.
    private var scope: Binding<SearchScope> {
        Binding(get: { .library }, set: { picked in
            guard picked == .everything else { return }
            model.searchQuery = model.searchText
            model.tab = .search
        })
    }
}
