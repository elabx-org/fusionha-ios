import SwiftUI
import FusionhaKit

/// The web's mobile item detail (`MobileDetailFlyout`): a large sheet with the
/// full-bleed art hero over a blurred ambient backdrop, the item actions rail,
/// the quality-editions switcher with its scoped reveal, the rails, and the
/// Seasons / Files (Editions) / History / Searches tabs. A glass compact bar
/// fades in once the hero has scrolled away.
struct ItemDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    let itemId: Int
    @State private var store: DetailStore
    @State private var compact = false

    init(itemId: Int) {
        self.itemId = itemId
        _store = State(initialValue: DetailStore(itemId: itemId))
    }

    private var reduceMotion: Bool {
        systemReduceMotion || store.settings?.animationsEnabled == false
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
            .ignoresSafeArea(.container, edges: .top)
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 200
            } action: { _, isPast in
                compact = isPast
            }
            .task(id: store.detail == nil) {
                guard store.detail != nil else { return }
                await screenshotScroll(proxy)
            }
        }
        .overlay(alignment: .top) {
            if compact, let title = store.detail?.title {
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
        .environment(store)
        .environment(\.detailReduceMotion, reduceMotion)
        .presentationDetents([.large])
        .presentationCornerRadius(14)
        .task {
            store.client = model.client
            store.queue = model.queue
            applyScreenshotEnvironment()
            await store.load()
        }
        .onChange(of: model.queue) { store.queue = model.queue }
        .onChange(of: store.deleted) {
            guard store.deleted else { return }
            Task { await model.loadLibrary() }
            dismiss()
        }
        .sheet(item: $store.interactive) { target in
            InteractiveSearchSheet(target: target)
                .environment(store)
                .environment(\.detailReduceMotion, reduceMotion)
        }
        .sheet(isPresented: $store.showingEdit) {
            if let detail = store.detail {
                EditItemSheet(detail: detail)
                    .environment(store)
            }
        }
        .sheet(item: $store.addPreset) { preset in
            if let detail = store.detail {
                AddEditionSheet(detail: detail, preset: preset)
                    .environment(store)
            }
        }
        .sheet(item: $store.seasonSheet) { ref in
            if let detail = store.detail, let season = detail.seasons?.first(where: { $0.seasonNumber == ref.number }) {
                SeasonActionsSheet(detail: detail, season: season)
                    .environment(store)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $store.showingDelete) {
            if let detail = store.detail {
                DeleteItemSheet(detail: detail)
                    .environment(store)
                    .presentationDetents([.height(300)])
            }
        }
    }

    private func close() { dismiss() }

    private func openWeb() {
        guard let server = model.credentials?.serverURL else { return }
        openURL(server.appendingPathComponent("library/\(itemId)"))
    }

    private func compactBar(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 9))
            .accessibilityLabel("Close detail")
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
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
        guard let sheet = env["FUSIONHA_SCREENSHOT_DETAIL_SHEET"], let detail = store.detail else { return }
        try? await Task.sleep(for: .seconds(1.2))
        switch sheet {
        case "search":
            let ids = store.scopedEditions.map(\.id)
            store.interactive = InteractiveTarget(editionIds: ids, episodeId: nil, seasonNumber: nil,
                                                  subtitle: "\(detail.title) · \(store.actsOnLabel)")
        case "edit": store.showingEdit = true
        case "add": store.addPreset = AddEditionPreset()
        case "delete": store.showingDelete = true
        default: break
        }
        #endif
    }
}

/// The hero art repeated behind everything: blurred, saturated and darkened,
/// under a `--bg` scrim (MobileDetailFlyout `.ambient`). Content, not glass.
private struct AmbientBackdrop: View {
    let url: String?

    var body: some View {
        ZStack {
            Theme.bg
            if let url {
                PosterImage(url: TMDBImage.resized(url, to: "w342"))
                    .scaleEffect(1.28)
                    .blur(radius: 72)
                    .saturation(1.4)
                    .brightness(-0.2)
                    .clipped()
            }
            LinearGradient(stops: [
                .init(color: Theme.bg.opacity(0.78), location: 0),
                .init(color: Theme.bg.opacity(0.62), location: 0.3),
                .init(color: Theme.bg.opacity(0.5), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

/// The scrolling page body.
private struct DetailPage: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let close: () -> Void
    let openWeb: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailHero(detail: detail, close: close)

            VStack(alignment: .leading, spacing: 0) {
                if let overview = detail.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 14))
                        .lineSpacing(14 * 0.55 - 3)
                        .foregroundStyle(Theme.txt.opacity(0.9))
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .detailReveal(delay: 0.18)
                }

                DetailSection(title: "Item actions")
                ItemActionsRail(detail: detail, openWeb: openWeb)
                (Text("acts on ").foregroundColor(Theme.dim)
                    + Text(store.actsOnLabel).font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundColor(Theme.txt))
                    .font(.system(size: 11.5))
                    .padding(.top, 8)
                    .contentTransition(.opacity)
                    .detailAnimation(.easeInOut(duration: 0.2), value: store.actsOnLabel)

                DetailSection(title: "Quality editions", see: "scope + search in one")
                    .id("editions")
                EditionsSwitcher(detail: detail)
                AutoSearchFlashStrip()
                GradualProgressStrip()

                if detail.kind == .movie, ReleaseTimeline.hasData(detail) {
                    DetailSection(title: "Release timeline")
                    ReleaseTimeline(detail: detail)
                }
                DetailRailStack(detail: detail)

                DetailTabsView(detail: detail, openWeb: openWeb)
                    .id("tabs")
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
    }
}
