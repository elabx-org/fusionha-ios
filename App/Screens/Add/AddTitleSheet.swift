import SwiftUI
import FusionhaKit

enum MetadataSource: Hashable {
    case tmdb, tvdb
}

/// What the Add sheet pushes: the "View details" preview of a title (zooming
/// out of `zoomId`), from the configure step's hero or a Find tile's eye.
struct AddDetailsRoute: Hashable {
    let route: PreviewRoute
    let zoomId: String
}

/// The web's Add dialog (AddItemModal.tsx) as a bottom sheet. Find searches
/// TMDB (or TVDB for series) with the trending grid while the field is empty;
/// the configure step (Add title v2, `AddConfigView`) sets up each version and
/// `POST /api/v1/library`. "View details" pushes the title's preview inside
/// the sheet with a zoom from the hero, and "Continue adding" zooms back to
/// the same configure state. Requester accounts get the request sheet instead.
struct AddTitleSheet: View {
    /// Open straight on this title's configure step (Discover, a preview page).
    var initialPick: AddPick?
    /// From a details page: no "View details" link back to it.
    var hideViewDetails = false
    /// Discover's session "Add as" provider.
    var providerOverride: String?
    /// After a successful add, with the new item's id.
    var onAdded: ((Int) -> Void)?

    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    @Environment(\.motionEnabled) var motion
    @Namespace var zoomSpace
    @State var path = NavigationPath()
    @State var flow: AddFlow?
    @State var requestPick: MediaSearchResult?
    @State var sessionProvider = "auto"
    @State var settings: AddSettings?
    @State var detent: PresentationDetent = .fraction(0.88)
    @State var kind: SearchKind = .all
    @State var source: MetadataSource = .tmdb
    @State var query = ""
    @State var gridView = true
    @State var results: [MediaSearchResult] = []
    @State var tvdbResults: [TvdbSearchResult] = []
    @State var trending: [MediaSearchResult] = []
    @State var trendingState: LoadState = .loading
    @State var searchState: LoadState = .idle
    @State var searchMissingKey = false
    @State var trendingMissingKey = false

    enum LoadState { case idle, loading, loaded, failed }

    var term: String { query.trimmingCharacters(in: .whitespaces) }
    var configuring: Bool { flow != nil || requestPick != nil }
    /// Optimistic while settings load: only an explicit `false` gates.
    var tmdbConfigured: Bool { settings?.tmdbConfigured != false }
    var tvdbConfigured: Bool { settings?.tvdbConfigured != false }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AddDetailsRoute.self) { details in
                    previewPage(details.route)
                        .modifier(ZoomTransition(id: details.zoomId, namespace: zoomSpace))
                }
                .navigationDestination(for: PreviewRoute.self) { route in
                    previewPage(route)
                }
        }
        .presentationDetents([.fraction(0.88), .large], selection: $detent)
        .onAppear(perform: start)
        .onChange(of: kind) { if kind == .movie { source = .tmdb } }
        .onChange(of: tvdbConfigured) { if !tvdbConfigured { source = .tmdb } }
        .task(id: kind) { await loadTrending() }
        .task(id: "\(term)|\(kind.rawValue)|\(source == .tvdb)") { await search() }
        .task { settings = try? await model.client?.addSettings() }
    }

    @ViewBuilder
    var root: some View {
        if let flow {
            AddConfigView(flow: flow, onSearchAgain: backToSearch, onViewDetails: viewDetailsAction(flow),
                          onClose: { dismiss() }, onAdded: { added($0, flow: flow) },
                          zoom: flow.pick.tmdbResult == nil ? nil : (id: heroZoomId(flow), namespace: zoomSpace))
                .id(flow.pick.key)
        } else if let requestPick {
            // A requester's pick goes through the one request path (web
            // `RequestModal`): versions, seasons, quota and the wishlist.
            RequestModal(pick: requestPick) { Task { await model.refreshShell() } }
                .id(requestPick.id)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    searchStep
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle(scale: 0.9))
                .accessibilityLabel("Close")
                .padding(.top, 8)
                .padding(.trailing, 6)
            }
            .background(Theme.panel)
        }
    }

    // MARK: Picks

    func start() {
        if let initialPick {
            sessionProvider = providerOverride ?? "auto"
            startFlow(initialPick)
        } else {
            sessionProvider = model.addProviderOverride ?? "auto"
            let prefill = model.addPrefill
            model.addPrefill = nil
            model.addProviderOverride = nil
            if let prefill { pick(prefill) }
        }
        #if DEBUG
        screenshotHooks()
        #endif
    }

    func startFlow(_ pick: AddPick) {
        withAnimation(motion ? .snappy(duration: 0.3) : nil) {
            flow = AddFlow(pick: pick, client: model.client,
                           providerOverride: sessionProvider == "auto" ? nil : sessionProvider)
            detent = .large
        }
    }

    func heroZoomId(_ flow: AddFlow) -> String { "hero-\(flow.pick.key)" }

    /// "View details": a TMDB pick's preview, pushed with a zoom from the hero.
    /// Not for a TVDB-only pick (no TMDB id), nor from a details page.
    func viewDetailsAction(_ flow: AddFlow) -> (() -> Void)? {
        guard !hideViewDetails, let result = flow.pick.tmdbResult else { return nil }
        return { path.append(AddDetailsRoute(route: PreviewRoute(result), zoomId: heroZoomId(flow))) }
    }

    /// The configure step's back: to Find, the box seeded with the title when
    /// the pick never came from it.
    func backToSearch() {
        let seed = flow?.title ?? requestPick?.title ?? ""
        if term.isEmpty && !seed.isEmpty { query = TitleYear.display(seed, nil).title }
        withAnimation(motion ? .snappy(duration: 0.3) : nil) {
            flow = nil
            requestPick = nil
        }
    }

    func pick(_ result: MediaSearchResult) {
        if result.inLibrary, let id = result.libraryItemId, !model.requestScoped {
            dismiss()
            model.open(id)
        } else if model.requestScoped {
            withAnimation(motion ? .snappy(duration: 0.3) : nil) { requestPick = result }
        } else {
            startFlow(.tmdb(result))
        }
    }

    func pickTvdb(_ result: TvdbSearchResult) {
        if result.inLibrary == true, let id = result.libraryItemId {
            dismiss()
            model.open(id)
        } else {
            startFlow(.tvdb(result))
        }
    }

    /// A Find tile's eye: the title's preview, zooming out of the tile.
    func preview(_ result: MediaSearchResult) {
        path.append(AddDetailsRoute(route: PreviewRoute(result), zoomId: "tile-\(result.id)"))
    }

    func isCurrent(_ route: PreviewRoute) -> Bool {
        guard let result = flow?.pick.tmdbResult else { return false }
        return PreviewRoute(result) == route
    }

    func previewPage(_ route: PreviewRoute) -> some View {
        PreviewPage(route: route, onAdd: { result in
            // "Continue adding" goes back to the same configure state; another
            // title starts its own.
            if !isCurrent(PreviewRoute(result)) { startFlow(.tmdb(result)) }
            path = NavigationPath()
        }, onOpenLibrary: { id in
            dismiss()
            model.open(id)
        }, continueAdding: isCurrent(route), onClose: { dismiss() }, onBack: {
            if !path.isEmpty { path.removeLast() }
        })
    }

    func added(_ item: AddedTitle, flow: AddFlow) {
        model.toast("\(flow.title) added")
        dismiss()
        Task { await model.loadLibrary() }
        onAdded?(item.id)
    }

}
