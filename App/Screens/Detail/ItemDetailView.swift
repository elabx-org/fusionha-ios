import SwiftUI
import FusionhaKit

/// The web's mobile item detail (`MobileDetailFlyout`): a large sheet with the
/// full-bleed art hero over a blurred ambient backdrop, the item actions rail,
/// the Versions panel (opening a row scopes the page), the rails, and the
/// Seasons / Files (Versions) / History / Searches tabs. A glass compact bar
/// fades in once the hero has scrolled away.
///
/// The store comes from `AppModel.detailStore(for:)`, so the sheet and the
/// shell's column show the same one: a fold / unfold keeps the page, its
/// scroll, and any child sheet with its draft (`DetailChildSheets`).
struct ItemDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// True when this is the shell's trailing column (unfolded) rather than a sheet:
    /// the close / refresh / web actions are then standard toolbar items, which
    /// the system can move to the side of the display in some postures.
    @Environment(\.detailInColumn) private var inColumn
    let store: DetailStore
    /// Closes the column; a sheet dismisses itself.
    var onClose: (() -> Void)?
    @State private var compact = false
    /// Child sheets show once ready: at once on the first host, after the old
    /// host has left on a re-host (fold / unfold).
    @State private var presentReady: Bool
    @State private var position = ScrollPosition(idType: String.self)

    private var itemId: Int { store.itemId }

    init(store: DetailStore, onClose: (() -> Void)? = nil) {
        self.store = store
        self.onClose = onClose
        _presentReady = State(initialValue: !store.hosted)
    }

    private var reduceMotion: Bool {
        systemReduceMotion || store.settings?.animationsEnabled == false
    }

    private var presenter: DetailPresenter {
        let host: DetailHost = inColumn ? .column : .sheet
        return DetailPresenter(store: store, ready: presentReady) { [model] in model.detailHostAccepts(host) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if let detail = store.detail {
                        DetailPage(detail: detail, close: close, openWeb: openWeb)
                    } else if store.loadError != nil {
                        EmptyBox(message: "This title could not be loaded.")
                            .padding(16)
                            .padding(.top, 80)
                    } else {
                        DetailSpinner(size: 22, color: Theme.mut)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 160)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollPosition($position)
            .ignoresSafeArea(.container, edges: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, y in
                store.scrollY = y
                if compact != (y > 200) { compact = y > 200 }
            }
            .task(id: store.detail == nil) {
                guard store.detail != nil else { return }
                applyIntent()
                await screenshotScroll(proxy)
            }
        }
        .overlay(alignment: .top) {
            if compact, !inColumn, let title = store.detail?.title {
                compactBar(title)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -6)))
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                DetailToastView(toast: toast) { store.toast = nil }
                    .padding(.bottom, 12)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(toast.action == nil ? 3.5 : 6))
                        if store.toast?.id == toast.id { store.toast = nil }
                    }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: compact)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: store.toast)
        .background { AmbientBackdrop(url: store.detail.flatMap { $0.posterUrl ?? $0.backdropUrl }) }
        .toolbar {
            if inColumn {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: "Close detail", action: close)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.load() } }
                    Button("Open in the web app", systemImage: "safari", action: openWeb)
                }
            }
        }
        .navigationTitle(inColumn && compact ? (store.detail?.title ?? "") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(inColumn && compact ? .visible : .hidden, for: .navigationBar)
        .environment(store)
        .environment(\.detailReduceMotion, reduceMotion)
        .presentationDetents([.large])
        .presentationCornerRadius(34)
        .task {
            store.client = model.client
            store.queue = model.queue
            applyScreenshotEnvironment()
            applyPendingTab()
            await store.load()
        }
        .onAppear { store.hosted = true }
        .task { await rehost() }
        .onChange(of: model.pendingDetailTab) { applyPendingTab() }
        .onChange(of: model.queue) { store.queue = model.queue }
        .onChange(of: store.deleted) {
            guard store.deleted else { return }
            Task { await model.loadLibrary() }
            close()
        }
        .modifier(DetailChildSheets(presenter: presenter, reduceMotion: reduceMotion))
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
        if inColumn { await DetailSheetPresence.settle(limit: .seconds(2)) }
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

    private func compactBar(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(Theme.display(22, relativeTo: .headline))
                .tracking(Theme.displayTracking(22))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
            Spacer(minLength: 0)
            GlassIconButton(systemName: "xmark", label: "Close detail", size: 40, action: close)
        }
        .padding(.horizontal, Theme.pageGutter)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        // Darkened so the page scrolling underneath never reads through the title.
        .background(Theme.bg.opacity(0.82))
        .glassEffect(.regular, in: .rect)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
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
        case "search":
            let ids = store.scopedEditions.map(\.id)
            store.interactive = InteractiveTarget(editionIds: ids, episodeId: nil, seasonNumber: nil,
                                                  subtitle: store.actsOnLabel)
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
