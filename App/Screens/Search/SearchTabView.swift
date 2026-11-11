import SwiftUI
import FusionhaKit

// MARK: - Search tab

/// The iOS 26 search tab: the unified search (owner-approved 2026-10-23). One
/// system field with the scopes Everything | This library; your library
/// answers instantly ("In your library", capped at 8), and every provider with
/// a key (TMDB through `/search/unified`, TheTVDB, the id lookup) answers as
/// you type ("Available to add", deduped and merged, `UnifiedSearchModel`). The field is focused when
/// the tab opens on the phone; wide, it opens on Trending.
///
/// On the open iPhone Duo: in a Spread the results stay on the left page and a
/// tapped result's preview opens on the right page; in the Web layout the list
/// stays before the fold (the web's palette would sit on it).
struct SearchTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread
    @Environment(\.motionEnabled) private var motion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.duoOpen) private var duoOpen
    /// v2 (S11): the palette's tint ground and W1 lanes.
    @Environment(\.browseLook) private var look
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
    @Environment(\.collapsedTabs) private var tabs
    /// Where the scroll's content starts on screen, and the column's width.
    @State private var restTop: CGFloat = 0
    @State private var column: CGFloat = 0

    /// Collapsed tabs (v2): typed results run under the Duo's column to the
    /// display's edge. Before typing, Trending keeps its place.
    // Beside an open title the list pane isn't under the column. Decided
    // from the page's state, never from the inset it measures: the measure
    // changes when the page ignores that inset, which fed back into itself.
    private var fullWidth: Bool {
        tabs.on && look != nil && !trimmed.isEmpty && !(duoOpen && model.rightPageHasItem)
    }
    /// Room above the first lane so a row's own buttons never start under
    /// the arrow button (`TabsLook.clearance`), less the kind picker's row.
    private var lead: CGFloat {
        guard fullWidth, restTop > 0 else { return 0 }
        return max(0, TabsLook.clearance(folded: !duoOpen, bottom: tabs.bottom) - restTop - (pickerOnRightPage ? 0 : 46))
    }

    private var trimmed: String { model.searchQuery.trimmingCharacters(in: .whitespaces) }
    private var kind: SearchKind { SearchKind(rawValue: kindRaw) ?? .all }
    /// v1: in a Spread with nothing open the kind filter sits on the right
    /// page. v2 keeps it above the results: Search spans the open Duo until
    /// a result is tapped (owner, 2026-11-09: no automatic split).
    private var pickerOnRightPage: Bool {
        look == nil && spread.isActive && model.spreadPreview == nil && model.presentedItem == nil
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
                        SearchKindPicker().frame(maxWidth: 520, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.pageGutter).padding(.bottom, 2)
                            // Beside the column's clock and arrow, not under them.
                            .padding(.trailing, fullWidth ? column : 0)
                    }
                    if lead > 0 { Color.clear.frame(height: lead) }
                    SearchResults(term: trimmed, kind: kind, search: search, filter: filter, actions: actions)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
            // The Web layout on the open Duo: the list before the fold.
            .foldLeadingColumn(!spread.isActive)
        }
        // The open Duo's keyboard covers half the results: any scroll puts it away.
        .scrollDismissesKeyboard(duoOpen ? .immediately : .interactively)
        .ignoresSafeArea(.container, edges: fullWidth ? .trailing : [])
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY + $0.safeAreaInsets.top } action: { restTop = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.trailing } action: { if $0 > 0 { column = $0 } }
        // Rows pass under the floating field and scopes: the hard edge keeps
        // their titles from reading through the glass.
        .scrollEdgeEffectStyle(.hard, for: .top)
        // The rows' Add fits its word only where the list has room (v2).
        .publishesPaneSize()
        .background { if look == nil { Theme.bg.ignoresSafeArea() } }
        .browseGround(look)
        .shellPage("Search")
        .searchable(text: $model.searchQuery,
                    prompt: SearchPrompt.text(requester: model.requestScoped, wide: duoOpen || sizeClass != .compact))
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
        // v2 spans while you type too: typed results use the whole open Duo
        // and the right page opens only when a result is tapped (no "Pick a
        // result" page). v1 keeps its split once you type.
        .spreadSpansBothPages(.search, trimmed.isEmpty || look != nil)
        // A result picked: the words join the recent searches and the keyboard
        // goes, so closing the result comes back to the results, not the keyboard.
        .onChange(of: store.preview) { if store.preview != nil { picked() } }
        .onChange(of: store.requestPick) { if store.requestPick != nil { picked() } }
        .onChange(of: tvdbPick) { if tvdbPick != nil { picked() } }
        .onChange(of: model.presentedItem?.id) { if model.presentedItem != nil, model.tab == .search { picked() } }
        .environment(store)
        // A requester's pick: the request modal (web OmniResults → RequestModal).
        .duoPageSheet(item: $store.requestPick, placement: .twoPages) { pick in
            NavigationStack { RequestModal(pick: pick) {} }
        }
        .duoPageSheet(item: $tvdbPick) { pick in
            AddTitleSheet(initialPick: .tvdb(pick)) { id in model.open(id) }
        }
        .spreadPreviewHost(.search, preview: $store.preview, onOpenLibrary: { model.open($0) })
        #if DEBUG
        .searchScreenshotPreview(search: search) { store.preview = PreviewRoute($0) }
        .searchScreenshotOpen($focused)
        #endif
        .task {
            // Open ready to type on the phone, as a search tab does. Wide (the
            // open Duo, iPad) it opens on Trending: the keyboard would cover
            // half of it; tap the field to type (owner, 2026-11-05).
            guard sizeClass == .compact else { return }
            try? await Task.sleep(for: .milliseconds(350))
            focused = true
        }
        .onChange(of: model.searchFocusTick) { if sizeClass == .compact { focused = true } }
        .task {
            if !model.requestScoped { await model.loadLibraryIfNeeded() }
        }
        .task(id: UnifiedSearchModel.key(trimmed, kind)) {
            await search.run(trimmed, kind: kind, source: model.client.map { ServerUnifiedSearchSource(client: $0, tmdb: .always) },
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
        model.pendingAllTitles = true
        model.tab = .library
        scope = .everything
    }

    private func picked() {
        focused = false
        remember()
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
