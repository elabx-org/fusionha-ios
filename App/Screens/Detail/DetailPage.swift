import SwiftUI
import FusionhaKit

/// The hero art repeated behind everything (MobileDetailFlyout `.ambient`):
/// blurred and saturated under a `--bg` scrim (`AmbientWash`). Dark palettes
/// use the web's 78 / 62 / 50 % and temper the art (`brightness(0.8)`); light
/// palettes keep the body near-white (94 % easing to solid), a faint tint
/// only, since the web's wash reads as tan fog on a light ground and drowns
/// secondary text. Content, not glass.
struct AmbientBackdrop: View {
    let url: String?

    var body: some View {
        ZStack {
            Theme.bg
            if let url {
                // Blurred, saturated and dimmed once into a cached bitmap
                // (`AmbientArt`), not a live blur(72) under the scrolling page.
                AmbientArt(url: TMDBImage.resized(url, to: "w780"), kind: .detailAmbient)
            }
            LinearGradient(stops: AmbientWash.stops(light: Theme.isLight).map {
                Gradient.Stop(color: Theme.bg.opacity($0.opacity), location: $0.location)
            }, startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

/// The scrolling page body (MobileDetailFlyout `.body`): setup strip,
/// overview, Item actions + its "applies to" echo, Versions, the release
/// timeline, the tabs (the rails live in their Overview tab) and the
/// metadata credit. On the folded Duo / phone (`detailCompact`) the item
/// actions live in the bar's More menu, and the Overview rails follow the
/// tabs in the page. On the open Duo's split title (`infoPage`, the left
/// page) the art is the band across both pages and the tabs are the right
/// page, so it is the facts, versions and the Overview rails.
struct DetailPage: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.detailCompact) private var compact
    let detail: ItemDetail
    let openWeb: () -> Void
    var infoPage = false
    /// The split title's left page: where its strip ends and Versions start,
    /// for the band's backdrop (`DetailSpreadBody`).
    var onMetrics: ((HeroHeaderMetrics) -> Void)?
    /// The split title's left page: the top of Versions on screen as it
    /// scrolls (only the backdrop reads it, so the page is not redrawn).
    var onVersionsOnScreen: ((CGFloat) -> Void)?
    @State private var metrics = HeroHeaderMetrics()
    /// The hero's height (its art's darkened edge) and the page's width.
    @State private var edge: CGFloat = 360
    @State private var width: CGFloat = 0

    private var gutter: CGFloat { infoPage ? 20 : Theme.pageGutter }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if infoPage {
                DetailHeroFacts(detail: detail) { metrics.stripEnd = $0 }
                    .padding(.horizontal, gutter)
            } else {
                DetailHero(detail: detail) { edge = $0 } onStripEnd: { metrics.stripEnd = $0 }
            }

            VStack(alignment: .leading, spacing: 0) {
                if let setup = model.setupProgress.activeSetup(for: detail.id) {
                    SetupStepStrip(setup: setup)
                        .padding(.top, 14)
                        .padding(.bottom, 4)
                }
                if let overview = detail.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 15))
                        .lineSpacing(15 * 0.45 - 3)
                        .foregroundStyle(Theme.txt)
                        .readableWidth()
                        .padding(.top, 16)
                        .detailReveal(delay: 0.18)
                }

                if !compact {
                    appliesTo
                        .id("actions")
                    ItemActionsRail(detail: detail, openWeb: openWeb)
                }

                // MobileDetailFlyout: the request strip sits above Versions.
                DetailRequestsStrip(itemId: detail.id)
                    .padding(.top, 14)
                    .id("requests")

                DetailVersionsPanel(detail: detail, openWeb: openWeb)
                    .id("editions")
                    .onGeometryChange(for: CGFloat.self) {
                        $0.frame(in: .named(Self.space)).minY
                    } action: { metrics.versionsTop = $0 }
                    .onGeometryChange(for: CGFloat.self) {
                        onVersionsOnScreen == nil ? 0 : $0.frame(in: .global).minY
                    } action: { onVersionsOnScreen?($0) }

                if detail.kind == .movie, ReleaseTimeline.hasData(detail) {
                    DetailSection(title: "Release timeline")
                    ReleaseTimeline(detail: detail)
                }

                if !infoPage {
                    DetailTabsView(detail: detail, openWeb: openWeb)
                        .id("tabs")
                        .padding(.top, 6)
                }

                if compact || infoPage {
                    DetailRailStack(detail: detail)
                        .id("overview")
                }

                MetadataCredit(provider: detail.resolvedMetadataProvider ?? "tmdb")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 32)
            }
            .padding(.horizontal, gutter)
            .padding(.bottom, 32)
        }
        .coordinateSpace(.named(Self.space))
        .background(alignment: .top) {
            if !infoPage { backdrop }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: metrics, initial: true) { onMetrics?(metrics) }
    }

    /// The single column's hero art: behind the hero, facts, overview and
    /// actions, fading out at the top of Versions (`DetailHeroBackdrop`).
    private var backdrop: some View {
        let handover = HeroBackdropLayout.handover(edge: edge, stripEnd: metrics.stripEnd)
        return DetailHeroBackdrop(
            url: ItemDetailArt.hero(backdrop: detail.backdropUrl, poster: detail.posterUrl),
            layout: HeroBackdropLayout(edge: edge, handover: handover,
                                       foot: max(metrics.versionsTop, handover + 48),
                                       column: HeroBackdropLayout.textColumn(width: width, gutter: gutter),
                                       farWash: false))
    }

    private static let space = "detailPage"

    /// The rail's caption (`.applies`): "Item actions · applies to {all
    /// versions | tier}", echoing the page scope the actions act on.
    private var appliesTo: some View {
        (Text("Item actions · applies to ")
            + Text(store.actsOnLabel).fontWeight(.semibold).foregroundColor(Theme.txt))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.dim)
            .padding(.top, 22)
            .padding(.bottom, 10)
            .contentTransition(.opacity)
            .detailAnimation(.easeInOut(duration: 0.2), value: store.actsOnLabel)
            .accessibilityAddTraits(.isHeader)
    }
}
