import SwiftUI
import FusionhaKit

// MARK: - RequestModal

struct RequestModal: View {
    @Environment(\.windowSize) private var window
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    let pick: MediaSearchResult
    /// A form sheet at regular width (ruling R3); off inside the Add sheet,
    /// which keeps its own size.
    var formSized = true
    let onDone: () -> Void

    @State var offer: OfferableEditions?
    @State var offerFailed = false
    @State var preview: MediaPreviewDetail?
    @State var selectedTiers: Set<QualityTier> = []
    @State var selSeasons: Set<Int> = []
    @State var selEpisodes: Set<EpisodeRef> = []
    @State var note = ""
    @State var sending = false
    @State var previewLoaded = false
    @State var demand: RequestTitleDemand?
    @State var quota: RequestQuota?
    /// The ask the server refused for quota; non-nil shows the wishlist prompt.
    @State var blocked: RequestCreateBody?
    /// The modal's own width: two panes above 720 (a page-sized Add sheet; the
    /// R3 form sheet stays one column).
    @State private var width: CGFloat = 0
    /// On the open iPhone Duo (`duoPageSheet(.twoPages)`): the title on the
    /// left page, the options on the right, the fold between them (S3).
    @State private var foldPanes: FoldColumns.Panes?

    var isSeries: Bool { pick.kind == .series }
    /// The versions on offer: the server's per-viewer demand list (join, Watch
    /// or a new ask) when it answered, else the offerable set.
    var offerTiers: [QualityTier] {
        guard let offer else { return [] }
        return RequestOffer.tiers(demand: demand, fallback: offer.isAuto ? offer.autoEditions : offer.editions)
    }
    var editionsToSend: [QualityTier] {
        guard let offer else { return [] }
        return offer.isAuto ? offerTiers : offerTiers.filter { selectedTiers.contains($0) }
    }
    var picks: [(tier: QualityTier, act: RequestOffer.Act)] {
        editionsToSend.map { ($0, RequestOffer.act(demand, tier: $0)) }
    }
    var joinTiers: [QualityTier] { picks.filter { $0.act == .join }.map(\.tier) }
    var nothingOfferable: Bool { offer != nil && offerTiers.isEmpty }
    var canSubmit: Bool { offer != nil && !nothingOfferable && !editionsToSend.isEmpty && !sending }

    var body: some View {
        Group {
            if let foldPanes {
                // The open Duo: the same two panes, meeting at the fold's gutter.
                twoPanes(art: CGFloat(foldPanes.lead), gap: CGFloat(foldPanes.gap))
            } else if DiscoverWidthRule.requestTwoPanes(Double(width)) {
                // Wide (web `.layout`, `300px 1fr` above 720): the art pane beside
                // the options, each scrolling on its own; the footer under the options.
                twoPanes(art: 300, gap: 0)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            RequestModalArt(pick: pick, preview: preview)
                            optionsPane
                        }
                    }
                    // v1: the art runs under the clear bar, as before the system
                    // Close. v2: a compact header that starts under Close.
                    .ignoresSafeArea(.container, edges: ProductLook.isV2 ? [] : .top)
                    footer
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onGeometryChange(for: FoldColumns.Panes?.self) { proxy in
            DiscoverFold.requestPanes(width: Double(proxy.size.width), fold: GridFold(proxy).foldRange)
        } action: { foldPanes = $0 }
        // Close is a system toolbar item (DC10); presenters give the modal a
        // stack (`NavigationStack { RequestModal(…) }`), the Add sheet its own.
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                SheetCancelButton(title: "Close") { dismiss() }
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .closeOnlyBars()
        // v1's solid panel sheet, or v2's system glass sheet (look pass family 5).
        .modifier(RequestModalChrome(formSized: formSized))
        // A form sheet on the Duo; page-sized when the window is desktop-wide,
        // so the art | options panes show as on the web's desktop modal.
        .modifier(RequestModalSizing(formSized: formSized, wide: window.isDesktopPane))
        .task { await load() }
    }

    /// The art pane `art` wide, `gap` kept empty (the fold and its gutter, or a
    /// hairline without one), then the options with the footer under them.
    private func twoPanes(art: CGFloat, gap: CGFloat) -> some View {
        HStack(spacing: 0) {
            ScrollView { RequestModalArt(pick: pick, preview: preview, sidePane: true) }
                .frame(width: art)
                .background(ProductLook.isV2 ? Color.clear : Theme.panel)
                .overlay(alignment: .trailing) {
                    if gap == 0 { Rectangle().fill(Theme.line).frame(width: 1) }
                }
            Color.clear.frame(width: gap)
            VStack(spacing: 0) {
                ScrollView { optionsPane.padding(.top, 26) }
                footer
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private func load() async {
        guard let client = model.client else { return }
        async let offerCall = client.offerableEditions(kind: pick.kind, tmdbId: pick.tmdbId)
        async let previewCall = client.previewDetail(kind: pick.previewKind, tmdbId: pick.tmdbId)
        async let demandCall = try? client.requestDemand(kind: pick.kind, tmdbIds: [pick.tmdbId])
        async let quotaCall = try? client.requestQuota()
        do {
            let loaded = try await offerCall
            demand = await demandCall?.first { $0.tmdbId == pick.tmdbId }
            quota = await quotaCall
            offer = loaded
            selectedTiers = Set(offerTiers)
        } catch {
            offerFailed = true
        }
        preview = try? await previewCall
        previewLoaded = true
    }
}
