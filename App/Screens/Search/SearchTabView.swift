import SwiftUI
import FusionhaKit

// MARK: - Search tab

/// The iOS 26 search tab: the unified search (owner-approved 2026-10-23). One
/// system field with the scopes Everything | This library; your library
/// answers instantly ("In your library", capped at 8), and every provider with
/// a key (TMDB, TheTVDB, the id lookup) answers as you type ("Available to
/// add", deduped and merged, `UnifiedSearchModel`). The field is focused when
/// the tab opens.
///
/// On the open iPhone Duo: in a Spread the results stay on the left page and a
/// tapped result's preview opens on the right page; in the Web layout the list
/// stays before the fold (the web's palette would sit on it).
struct SearchTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread
    @Environment(\.motionEnabled) private var motion
    /// The preview and request sheets the rows open (shared with Discover's cards).
    @State private var store = DiscoverStore()
    @State private var search = UnifiedSearchModel()
    @State private var scope: SearchScope = .everything
    /// A TheTVDB-only title's Add sheet.
    @State private var tvdbPick: TvdbSearchResult?
    @AppStorage("unifiedSearch.sources") private var sourcesRaw = UnifiedSearchSourceFilter.all.rawValue
    @AppStorage(SearchKindPicker.storageKey) private var kindRaw = SearchKind.all.rawValue
    @State private var recent = RecentSearches.load(from: .standard)
    @FocusState private var focused: Bool

    private var trimmed: String { model.searchQuery.trimmingCharacters(in: .whitespaces) }
    private var kind: SearchKind { SearchKind(rawValue: kindRaw) ?? .all }
    /// In a Spread with nothing open the kind filter sits on the right page.
    private var pickerOnRightPage: Bool {
        spread.isActive && model.spreadPreview == nil && model.presentedItem == nil
    }

    private var filter: Binding<UnifiedSearchSourceFilter> {
        Binding { UnifiedSearchSourceFilter(rawValue: sourcesRaw) ?? .all } set: { sourcesRaw = $0.rawValue }
    }

    var body: some View {
        @Bindable var model = model
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if trimmed.isEmpty {
                    SearchBeforeTyping(kind: kind, search: search, recent: recent.terms,
                                       run: { model.searchQuery = $0 }, forget: forget)
                } else {
                    if !pickerOnRightPage {
                        SearchKindPicker().padding(.horizontal, Theme.pageGutter).padding(.bottom, 2)
                    }
                    SearchResults(term: trimmed, kind: kind, search: search, filter: filter, actions: actions)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
            // The Web layout on the open Duo: the list before the fold.
            .foldLeadingColumn(!spread.isActive)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg.ignoresSafeArea())
        .shellPage("Search")
        .searchable(text: $model.searchQuery,
                    prompt: model.requestScoped ? "Find something to request…" : "Search your library or add something new…")
        .searchScopes($scope) {
            if !model.requestScoped {
                Text("Everything").tag(SearchScope.everything)
                Text("This library").tag(SearchScope.library)
            }
        }
        .searchFocused($focused)
        // Typing survives a fold, unfold or rotation (D5).
        .keepsFocusAcrossResize($focused)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onSubmit(of: .search) { remember() }
        .onChange(of: scope) { _, picked in
            if picked == .library { handToLibrary() }
        }
        // Before you type, Trending spans both pages of a Spread.
        .spreadSpansBothPages(.search, trimmed.isEmpty)
        // A result picked: the words join the recent searches.
        .onChange(of: store.preview) { if store.preview != nil { remember() } }
        .onChange(of: store.requestPick) { if store.requestPick != nil { remember() } }
        .onChange(of: tvdbPick) { if tvdbPick != nil { remember() } }
        .onChange(of: model.presentedItem?.id) { if model.presentedItem != nil, model.tab == .search { remember() } }
        .environment(store)
        // A requester's pick: the request modal (web OmniResults → RequestModal).
        .duoPageSheet(item: $store.requestPick, placement: .twoPages) { pick in
            NavigationStack { RequestModal(pick: pick) {} }
        }
        .duoPageSheet(item: $tvdbPick) { pick in
            AddTitleSheet(initialPick: .tvdb(pick)) { id in model.open(id) }
        }
        .spreadPreviewHost(.search, preview: $store.preview, onOpenLibrary: { model.open($0) })
        .task {
            // Open ready to type, as a search tab does.
            try? await Task.sleep(for: .milliseconds(350))
            focused = true
        }
        .onChange(of: model.searchFocusTick) { focused = true }
        .task {
            if !model.libraryLoaded && !model.requestScoped { await model.loadLibrary() }
        }
        .task(id: UnifiedSearchModel.key(trimmed, kind)) {
            await search.run(trimmed, kind: kind, source: model.client.map { ClientUnifiedSearchSource(client: $0) },
                             motion: motion)
        }
    }

    private var actions: SearchAddActions {
        SearchAddActions(preview: { store.preview = PreviewRoute($0) },
                         request: { store.requestPick = $0 },
                         addTvdb: { tvdbPick = $0 })
    }

    /// "This library" filters the Library grid in place (it keeps its filters),
    /// as the web's header scope does; the Search tab stays on Everything.
    private func handToLibrary() {
        model.searchText = trimmed
        model.searchScope = .library
        model.tab = .library
        scope = .everything
    }

    private func remember() {
        recent.record(trimmed)
        recent.save(to: .standard)
    }

    private func forget(_ term: String) {
        recent.remove(term)
        recent.save(to: .standard)
    }
}
