import SwiftUI
import FusionhaKit

/// v2's title page (slice S5), shown wherever v1 shows `ItemDetailView`
/// (`TitlePageHost`): the sheet when folded, the shell's column when open.
/// One scrolling column on the art-palette ground (`.v2PageGround`, the
/// hero's art lifted and painted down the whole page), never split at the
/// fold. It runs on v1's `DetailStore` with v1's loading, live queue, toast
/// and fold / unfold re-hosting, so every action calls the same code as v1.
/// Seasons and episodes push over it (`V2TitleRoute`, slice S6); its sheets
/// are `V2TitleSheets` (v2's search and delete, v1's others).
struct V2TitleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.detailInColumn) private var inColumn
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
    @Environment(\.duoListToggle) private var listToggle
    let store: DetailStore
    var onClose: (() -> Void)?
    @State private var compact = false
    @State private var presentReady: Bool
    @State private var position = ScrollPosition(idType: String.self)
    @State private var width: CGFloat = 0
    /// The bar's reach down the scroll view (`v2TitleBarInset`).
    @State private var barInset: CGFloat = 0
    /// The poster-led page on trial (Account › This iPhone).
    @AppStorage(TitleLook.posterKey) private var posterLook = false

    init(store: DetailStore, onClose: (() -> Void)? = nil) {
        self.store = store
        self.onClose = onClose
        _presentReady = State(initialValue: !store.hosted)
    }

    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var canSearch: Bool { canEdit && (model.me?.can("search") ?? true) }
    private var compactLayout: Bool { !inColumn && sizeClass == .compact }
    private var reduceMotion: Bool { systemReduceMotion || store.settings?.animationsEnabled == false }
    /// The list hidden on the flat open Duo: the band and two columns (S7).
    private var wide: Bool {
        inColumn && V2TitleWide.fills(duoOpen: duoOpen, bookPose: bookPose, toggle: listToggle)
    }

    private var presenter: DetailPresenter {
        let host: DetailHost = inColumn ? .column : .sheet
        return DetailPresenter(store: store, ready: presentReady) { [model] in model.detailHostAccepts(host) }
    }

    /// The hero's art, the ground's source (`V2Page.title`: its own backdrop).
    private var groundArt: URL? {
        let seed = model.library.first { $0.id == store.itemId }
        return PageArtSource.url(backdrop: store.detail?.backdropUrl ?? seed?.backdropUrl,
                                 poster: store.detail?.posterUrl ?? seed?.posterUrl)
    }

    var body: some View {
        let _ = PerfCount.hit("V2TitleView.body")
        let _ = PerfCount.mark("title.body")
        scroll
            .v2PageGround(art: groundArt, showsArt: false)
            .overlay(alignment: .top) { V2TitleToast(store: store, reduceMotion: reduceMotion) }
            .navigationTitle(compact ? (store.detail?.title ?? "") : "")
            .navigationSubtitle(compact ? subtitle : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(compact ? .visible : .hidden, for: .navigationBar)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: compact)
            .toolbar {
                V2TitleToolbar(store: store, canEdit: canEdit, canSearch: canSearch, escapeCloses: !inColumn,
                               close: close, openWeb: openWeb)
            }
            .environment(store)
            .environment(\.detailReduceMotion, reduceMotion)
            .environment(\.detailCompact, compactLayout)
            // v1 cards on this page (History's insights) take its W1 card.
            .environment(\.detailCardSurface, { radius in AnyView(ModuleSurface(radius: radius)) })
            .presentationDetents([.large])
            .presentationCornerRadius(34)
            .task {
                store.client = model.client
                store.queue = model.queue.filter { $0.mediaItemId == store.itemId }
                applyPendingTab()
                await store.load()
            }
            .task(id: store.detail == nil) {
                if store.detail != nil { PerfCount.mark("title.detail"); applyIntent() }
            }
            .onAppear { PerfCount.mark("title.appear"); store.hosted = true }
            .task { await rehost() }
            .onChange(of: model.pendingDetailTab) { applyPendingTab() }
            // Only this title's rows; a finished download re-fetches the item.
            .v2TitleLiveImport(store)
            .onChange(of: store.changes) { model.refreshLibrarySoon() }
            .onChange(of: store.deleted) {
                guard store.deleted else { return }
                Task { await model.loadLibrary() }
                store.episodeSheet = nil
                close()
            }
            .v2TitleDestinations(store: store, reduceMotion: reduceMotion)
            .modifier(V2FoldScreenshot(store: store))
            .modifier(V2TitleSheets(presenter: presenter, reduceMotion: reduceMotion))
    }

    /// The compact bar's second line (mock `cbar .tt small`): "2026 · HD 6/7 ·
    /// 4K 6/7" for a series, "2025 · Movie · HD and 4K on disk" for a movie.
    private var subtitle: String {
        guard let detail = store.detail else { return "" }
        let versions = V2TitleVersion.all(store, detail: detail)
        var parts: [String] = detail.year.map { [String($0)] } ?? []
        if detail.isSeries {
            parts += versions.compactMap { v in v.count.map { "\(v.edition.tier.badgeLetters) \($0)" } }
        } else {
            parts.append("Movie")
            var tiers: [String] = []
            for v in versions where v.have > 0 && !tiers.contains(v.edition.tier.badgeLetters) {
                tiers.append(v.edition.tier.badgeLetters)
            }
            if !tiers.isEmpty { parts.append("\(tiers.joined(separator: " and ")) on disk") }
        }
        return parts.joined(separator: " · ")
    }

    private var scroll: some View {
        ScrollView {
            Group {
                if let detail = store.detail {
                    switch (wide, posterLook) {
                    case (true, true): V2PosterWidePage(detail: detail, width: width)
                    case (true, false): V2TitleWidePage(detail: detail, width: width)
                    case (false, true): V2PosterTitlePage(detail: detail, width: width)
                    case (false, false): V2TitlePage(detail: detail, width: width)
                    }
                } else if store.loadError != nil {
                    DetailLoadError(close: close)
                } else if posterLook {
                    V2PosterLoadingShell(seed: model.library.first { $0.id == store.itemId }, width: width, wide: wide)
                } else {
                    DetailLoadingShell(seed: model.library.first { $0.id == store.itemId })
                }
            }
            .pinnedToProposedWidth()
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: wide)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectHidden(!compact, for: .top)
        .scrollPosition($position)
        .duoColumnPullSource()
        .ignoresSafeArea(.container, edges: .top)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { barInset = $0 }
        .environment(\.v2TitleBarInset, barInset)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, y in
            store.scrollY = y
            // The compact bar once the hero (or the shorter band) is gone.
            let past = y > (wide ? (posterLook ? 400 : 96) : (posterLook ? 420 : 240))
            if compact != past { compact = past }
        }
    }

    /// After a fold / unfold: back to the same offset, then (once the old
    /// host has left) re-present whichever child sheet was up (v1's rule).
    private func rehost() async {
        guard !presentReady else { return }
        let y = store.scrollY
        try? await Task.sleep(for: .milliseconds(80))
        if y > 0 { position.scrollTo(y: y) }
        if inColumn { await model.sheetPresence.settle(limit: .seconds(2)) }
        try? await Task.sleep(for: .milliseconds(inColumn ? 150 : 550))
        presentReady = true
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    /// What the poster menu asked for when it opened this title (v1's intents).
    private func applyIntent() {
        guard let intent = model.detailIntent, let detail = store.detail else { return }
        model.detailIntent = nil
        switch intent {
        case .edit:
            store.showingEdit = true
        case .interactiveSearch(let tier):
            let editions = tier.map { t in detail.orderedEditions.filter { $0.tier == t } } ?? detail.orderedEditions
            let picked = editions.isEmpty ? detail.orderedEditions : editions
            guard !picked.isEmpty else { return }
            store.interactive = InteractiveTarget(editionIds: picked.map(\.id),
                                                  subtitle: picked.count == 1 ? picked[0].label : "All versions")
        case .scopedSearch(let scope):
            store.interactive = InteractiveTarget(editionIds: scope.editionIds, episodeId: scope.episodeId,
                                                  seasonNumber: scope.seasonNumber, subtitle: scope.subtitle)
        }
    }

    private func openWeb() {
        guard let server = model.credentials?.serverURL else { return }
        openURL(server.appendingPathComponent("library/\(store.itemId)"))
    }

    private func applyPendingTab() {
        guard let tab = model.pendingDetailTab else { return }
        model.pendingDetailTab = nil
        store.tab = tab
    }
}
