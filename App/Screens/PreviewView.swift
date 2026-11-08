import SwiftUI
import FusionhaKit

/// The Preview page for a title not in the library (`routes/PreviewDetail.tsx`,
/// mobile `PreviewFlyout`): a full-height sheet with the ambient art bleed, the
/// bottom-anchored hero, then overview, the add/request action, seasons,
/// trailer, "More like this" (pushes another preview) and cast.
struct PreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let route: PreviewRoute
    /// Closes the sheet and opens the library item.
    let onOpenLibrary: (Int) -> Void
    /// "+ Add to library" opens the page's own Add sheet straight on the
    /// configure step, with Discover's session provider (web `PreviewAddSection`).
    @State private var addPick: MediaSearchResult?

    var body: some View {
        NavigationStack {
            PreviewPage(route: route, onAdd: { addPick = $0 }, onOpenLibrary: onOpenLibrary)
                .navigationDestination(for: PreviewRoute.self) { next in
                    // Close shuts the sheet; the system Back pops this page.
                    PreviewPage(route: next, onAdd: { addPick = $0 }, onOpenLibrary: onOpenLibrary,
                                onClose: { dismiss() })
                }
        }
        .presentationDragIndicator(.visible)
        .sheetBackground(Theme.bg)
        .presentationCornerRadius(14)
        // Sheets hide the shell's toasts.
        .overlay(alignment: .top) { ToastHost().padding(.top, 12) }
        .duoPageSheet(item: $addPick) { pick in
            AddTitleSheet(initialPick: .tmdb(pick), hideViewDetails: true,
                          providerOverride: DiscoverSession.shared.providerOverride) { id in
                // Added from the details page: open the new item (web navigates there).
                onOpenLibrary(id)
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
            .sheetBackground(Theme.panel)
        }
    }
}

struct PreviewPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let route: PreviewRoute
    let onAdd: (MediaSearchResult) -> Void
    let onOpenLibrary: (Int) -> Void
    /// The Add sheet's "View details" pushed this page for its current pick:
    /// the add button reads "Continue adding" and goes back to it.
    var continueAdding = false
    /// What Close does when it isn't `dismiss` (a pushed page closes its whole
    /// sheet; the Spread's right page closes the page). A pushed page's Back
    /// is the system one, so the edge swipe keeps working.
    var onClose: (() -> Void)?
    /// Escape presses Close (off on the Spread's right page, which isn't a sheet).
    var escapeCloses = true

    @State private var detail: MediaPreviewDetail?
    @State private var failed = false
    @State private var compact = false
    @State private var requestPick: MediaSearchResult?
    @State private var entered = false
    /// v2's browse look (look pass family 5): the art's page ground and its
    /// inks instead of v1's ambient bleed (`PreviewBody`).
    @Environment(\.browseLook) private var look

    private var me: Me? { model.me }
    private var canAdd: Bool { me.map { $0.hasCapability("add") } ?? !model.requestScoped }
    private var canRequest: Bool { me?.hasCapability("request") ?? false }

    var body: some View {
        ZStack(alignment: .top) {
            if look == nil { ambient }
            if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(detail)
                        PreviewBody(detail: detail, canAdd: canAdd, canRequest: canRequest,
                                    continueAdding: continueAdding, onAdd: onAdd,
                                    onRequest: { requestPick = $0 }, onOpenLibrary: onOpenLibrary)
                    }
                    .opacity(entered || DiscoverMotion.reduced(reduceMotion) ? 1 : 0)
                    .offset(y: entered || DiscoverMotion.reduced(reduceMotion) ? 0 : 24)
                }
                .scrollIndicators(.hidden)
                // The hero runs full-bleed under the clear system bar; the
                // bar's edge effect only comes in once the title takes over.
                .ignoresSafeArea(.container, edges: .top)
                .scrollEdgeEffectHidden(!compact, for: .top)
                .duoColumnPullSource()
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 200 } action: { _, new in
                    withAnimation(DiscoverMotion.reduced(reduceMotion) ? nil : .easeOut(duration: 0.2)) { compact = new }
                }
            } else if failed {
                VStack(spacing: 14) {
                    (Text("That title could not be found on TMDB. Head back to ")
                        + Text("Discover").foregroundColor(Theme.i2).fontWeight(.semibold) + Text("."))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .onTapGesture { dismiss() }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 80)
                .frame(maxWidth: .infinity)
            } else {
                PreviewSkeleton()
            }
        }
        .background(look == nil ? Theme.bg : Color.clear)
        .browseGround(look, backdrop: detail?.backdropUrl, poster: detail?.posterUrl)
        // The system bar, clear over the hero: Close, the system Back on a
        // pushed page, then Add. Scrolled past the hero, it takes the title.
        .navigationTitle(compact ? (detail?.title ?? "") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbar { toolbarItems }
        .task(id: route) { await load() }
        // On the open Duo: the title on the left page, the options on the right.
        .duoPageSheet(item: $requestPick, placement: .twoPages) { pick in
            NavigationStack { RequestModal(pick: pick) {} }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let loaded = try await client.discoverPreview(kind: route.kind, tmdbId: route.tmdbId)
            detail = loaded
            failed = false
            if DiscoverMotion.reduced(reduceMotion) {
                entered = true
            } else {
                withAnimation(DiscoverMotion.flyout()) { entered = true }
            }
        } catch is CancellationError {
        } catch {
            failed = true
        }
    }

    // MARK: Ambient bleed + toolbar

    private var ambient: some View {
        PreviewAmbient(art: detail?.posterUrl ?? detail?.backdropUrl)
    }

    private func close() { (onClose ?? { dismiss() })() }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCancelButton(title: "Close", escapeCloses: escapeCloses) { close() }
        }
        if let detail, !detail.inLibrary, canAdd {
            ToolbarItem(placement: .confirmationAction) {
                ToolbarActionButton(title: continueAdding ? "Continue adding" : "Add to library",
                                    systemImage: "plus") { onAdd(detail.asSearchResult) }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.indigo)
            }
        }
    }

    // MARK: Hero

    private func hero(_ d: MediaPreviewDetail) -> some View {
        PreviewHero(art: d.posterUrl ?? d.backdropUrl, status: d.status, title: d.title, year: d.year,
                    tagline: d.tagline, meta: heroMeta(d), genres: d.genres ?? [], oneInk: look != nil)
    }

    private func heroMeta(_ d: MediaPreviewDetail) -> [PreviewHero.Meta] {
        var items: [PreviewHero.Meta] = [.text(d.kind == .movie ? (d.isAnime ? "Anime Movie" : "Movie") : (d.isAnime ? "Anime" : "Series"))]
        if let runtime = d.runtime, runtime > 0 { items.append(.text("\(runtime) min")) }
        if let vote = d.voteAverage, vote > 0 { items.append(.rating(vote)) }
        if let cert = d.certification, !cert.isEmpty { items.append(.cert(cert)) }
        return items
    }
}
