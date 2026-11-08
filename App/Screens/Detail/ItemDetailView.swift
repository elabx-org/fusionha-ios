import SwiftUI
import FusionhaKit

/// The web's mobile item detail (`MobileDetailFlyout`): a large sheet with the
/// full-bleed art hero over a blurred ambient backdrop, the item actions rail,
/// the Versions panel (opening a row scopes the page), the rails, and the
/// Seasons / Files (Versions) / History / Searches tabs. The bar is
/// `ItemDetailToolbar` (Close · Search all · Refresh · More) in the sheet and
/// the column alike (D2); it takes the title once the hero has scrolled away.
///
/// The store comes from `AppModel.detailStore(for:)`, so the sheet and the
/// shell's column show the same one: a fold / unfold keeps the page, its
/// scroll, and any child sheet with its draft (`DetailChildSheets`).
struct ItemDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// True when this is the shell's trailing column (unfolded) rather than a sheet.
    @Environment(\.detailInColumn) private var inColumn
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The open Duo's halves while this title is a Spread's right page.
    @Environment(\.titleSpread) private var titleSpread
    let store: DetailStore
    /// Closes the column; a sheet dismisses itself.
    var onClose: (() -> Void)?
    @State private var compact = false
    /// Child sheets show once ready: at once on the first host, after the old
    /// host has left on a re-host (fold / unfold).
    @State private var presentReady: Bool
    @State private var position = ScrollPosition(idType: String.self)
    /// The single column's offset when the title split at the fold, so it
    /// comes back to the same place.
    @State private var savedY: CGFloat = 0

    private var itemId: Int { store.itemId }

    init(store: DetailStore, onClose: (() -> Void)? = nil) {
        self.store = store
        self.onClose = onClose
        _presentReady = State(initialValue: !store.hosted)
    }

    private var canEdit: Bool { model.me?.can("edit") ?? true }

    /// The folded Duo / phone layout (`detailCompact`): a sheet in a compact-width window.
    private var compactLayout: Bool { !inColumn && sizeClass == .compact }

    private var reduceMotion: Bool {
        systemReduceMotion || store.settings?.animationsEnabled == false
    }

    /// The title fills the open display in a Spread: it splits at the fold.
    private var splitPages: SpreadGeometry.Pages? {
        guard inColumn, let titleSpread, titleSpread.fillsDisplay else { return nil }
        return titleSpread.pages
    }

    /// A Spread's right page: an episode opens beside the title, not as a cover.
    private var episodesInline: Bool { inColumn && titleSpread != nil }

    private var presenter: DetailPresenter {
        let host: DetailHost = inColumn ? .column : .sheet
        return DetailPresenter(store: store, ready: presentReady) { [model] in model.detailHostAccepts(host) }
    }

    var body: some View {
        let _ = PerfCount.hit("ItemDetailView.body")
        page
            .modifier(DetailPageChrome(store: store, compact: compact && splitPages == nil, reduceMotion: reduceMotion))
            .toolbar {
                // In the shell's column it isn't a sheet: Escape stays with the page.
                ItemDetailToolbar(store: store, canEdit: canEdit, canSearch: canEdit && (model.me?.can("search") ?? true),
                                  compact: compactLayout, escapeCloses: !inColumn, close: close, openWeb: openWeb)
            }
            .environment(store)
            .environment(\.detailReduceMotion, reduceMotion)
            .environment(\.detailCompact, compactLayout)
            .presentationDetents([.large])
            .presentationCornerRadius(34)
            .task {
                store.client = model.client
                store.queue = model.queue.filter { $0.mediaItemId == store.itemId }
                applyScreenshotEnvironment()
                applyPendingTab()
                await store.load()
            }
            .task(id: store.detail == nil) {
                if store.detail != nil { applyIntent() }
            }
            .onAppear { store.hosted = true }
            .task { await rehost() }
            .onChange(of: model.pendingDetailTab) { applyPendingTab() }
            // Only this title's rows: another download's progress leaves the page alone.
            .onQueueChange(model) { [store] queue in
                let mine = queue.filter { $0.mediaItemId == store.itemId }
                if store.queue != mine { store.queue = mine }
            }
            .onChange(of: store.changes) { model.refreshLibrarySoon() }
            .onChange(of: store.deleted) {
                guard store.deleted else { return }
                Task { await model.loadLibrary() }
                // The column's Close closes an open episode first: the title goes.
                store.episodeSheet = nil
                close()
            }
            .onChange(of: splitPages == nil) { _, single in
                if single { restoreSingleColumn() } else { savedY = store.scrollY }
            }
            // On the open Duo its sheets open on the right page (`duoPageSheet`);
            // in a Spread the episode is the right page itself (`DetailSpreadBody`).
            .modifier(DetailChildSheets(presenter: presenter, reduceMotion: reduceMotion, episodeInline: episodesInline))
    }

    /// One scrolling column, or the title split at the fold (`DetailSpreadBody`).
    @ViewBuilder
    private var page: some View {
        if let pages = splitPages, let detail = store.detail {
            DetailSpreadBody(detail: detail, pages: pages, episodeReady: presentReady, openWeb: openWeb)
        } else {
            singleColumn
        }
    }

    private var singleColumn: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if let detail = store.detail {
                        DetailPage(detail: detail, openWeb: openWeb)
                    } else if store.loadError != nil {
                        DetailLoadError(close: close)
                    } else {
                        DetailLoadingShell(seed: model.library.first { $0.id == itemId })
                    }
                }
                // Exactly the width the scroll view offers, leading-aligned:
                // a row wider than the screen can only run off the trailing
                // side, never shift the page left (the folded Duo, beside the
                // system column). Measuring the scroll geometry instead
                // counted the column's inset twice and narrowed the page.
                .pinnedToProposedWidth()
                // The art ground (`AmbientBackdrop`) is behind every card on
                // this page: lifted cards let its colour bleed through.
                .environment(\.cardBleed, true)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollIndicators(.hidden)
            // Under the compact title the page blurs away instead of ghosting
            // through; over the hero the bar stays clear (as Preview does).
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectHidden(!compact, for: .top)
            .scrollPosition($position)
            .duoColumnPullSource()
            .ignoresSafeArea(.container, edges: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, y in
                store.scrollY = y
                if compact != (y > 200) { compact = y > 200 }
            }
            .onChange(of: store.versionReveal) { _, reveal in
                guard let reveal else { return }
                Task { await DetailRevealScroll.run(reveal, store: store, proxy: proxy, reduce: reduceMotion) }
            }
            .onChange(of: store.revealRequests) {
                if reduceMotion { proxy.scrollTo("requests", anchor: .center) } else {
                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo("requests", anchor: .center) }
                }
            }
            .task(id: store.detail == nil) {
                guard store.detail != nil else { return }
                await screenshotScroll(proxy)
            }
        }
    }

    /// Back from the split: the single column at the offset it had.
    private func restoreSingleColumn() {
        let y = savedY
        guard y > 0 else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            position.scrollTo(y: y)
        }
    }

    /// After a fold / unfold: back to the same scroll offset, then (once the
    /// old host has left, so UIKit does not drop the presentation) re-present
    /// whichever child sheet was up.
    private func rehost() async {
        guard !presentReady else { return }
        let y = store.scrollY
        try? await Task.sleep(for: .milliseconds(80))
        if y > 0 { position.scrollTo(y: y) }
        // Unfolded: the old sheet must be fully gone. Folded: this sheet must be up.
        if inColumn { await model.sheetPresence.settle(limit: .seconds(2)) }
        try? await Task.sleep(for: .milliseconds(inColumn ? 150 : 550))
        presentReady = true
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    /// What the poster menu asked for when it opened this sheet (read once, then cleared).
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
            let subtitle = picked.count == 1 ? picked[0].label : "All versions"
            store.interactive = InteractiveTarget(editionIds: picked.map(\.id), subtitle: subtitle)
        case .scopedSearch(let scope):
            store.interactive = InteractiveTarget(editionIds: scope.editionIds, episodeId: scope.episodeId,
                                                  seasonNumber: scope.seasonNumber, subtitle: scope.subtitle)
        }
    }

    private func openWeb() {
        guard let server = model.credentials?.serverURL else { return }
        openURL(server.appendingPathComponent("library/\(itemId)"))
    }

    private func applyPendingTab() {
        guard let tab = model.pendingDetailTab else { return }
        model.pendingDetailTab = nil
        store.tab = tab
    }

    // MARK: CI screenshots

    private func applyScreenshotEnvironment() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let tab = env["FUSIONHA_SCREENSHOT_DETAIL_TAB"].flatMap(DetailTab.init(rawValue:)) { store.tab = tab }
        // Shots run back to back on one simulator: never inherit the last one's scope.
        if env["FUSIONHA_SCREENSHOT_ITEM"] != nil { store.scope = DetailScope.parse(env["FUSIONHA_SCREENSHOT_DETAIL_SCOPE"]) }
        #endif
    }

    private func screenshotScroll(_ proxy: ScrollViewProxy) async {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let anchor = env["FUSIONHA_SCREENSHOT_DETAIL_SCROLL"] {
            try? await Task.sleep(for: .seconds(1.2))
            proxy.scrollTo(anchor, anchor: .top)
        }
        guard let sheet = env["FUSIONHA_SCREENSHOT_DETAIL_SHEET"], store.detail != nil else { return }
        try? await Task.sleep(for: .seconds(1.2))
        switch sheet {
        case "search": store.openInteractiveSearch()
        case "edit": store.showingEdit = true
        case "add": store.addPreset = AddEditionPreset()
        case "delete": store.showingDelete = true
        case "rename": store.openRename()
        case "aliases": store.showingAliases = true
        case "numbering": store.showingNumbering = true
        case "issue": store.showingIssue = true
        default: break
        }
        #endif
    }
}
