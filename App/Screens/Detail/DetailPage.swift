import SwiftUI
import FusionhaKit

/// The hero art repeated behind everything (MobileDetailFlyout `.ambient`):
/// blurred and saturated under a `--bg` scrim of the web's values, 78% at the
/// top to 50% at the foot (hero-art.module.css), so the whole page carries a
/// light tint of the art. Dark themes temper it (`brightness(0.8)`); Daylight
/// keeps it bright, so it never reads as grey fog. Content, not glass.
struct AmbientBackdrop: View {
    let url: String?

    var body: some View {
        ZStack {
            Theme.bg
            if let url {
                // SwiftUI-drawn art: the blur and colour effects reach it.
                SoftArt(url: TMDBImage.resized(url, to: "w780"))
                    .scaleEffect(1.28)
                    .blur(radius: 72)
                    .saturation(Theme.isMono ? 0 : 1.4)
                    .brightness(Theme.isLight ? 0 : -0.2)
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

/// The scrolling page body (MobileDetailFlyout `.body`): setup strip,
/// overview, Item actions + its "applies to" echo, Versions, the release
/// timeline, the rails, the tabs and the metadata credit.
struct DetailPage: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let openWeb: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailHero(detail: detail)

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
                        .padding(.top, 16)
                        .detailReveal(delay: 0.18)
                }

                appliesTo
                    .id("actions")
                ItemActionsRail(detail: detail, openWeb: openWeb)

                // MobileDetailFlyout: the request strip sits above Versions.
                DetailRequestsStrip(itemId: detail.id)
                    .padding(.top, 14)
                    .id("requests")

                DetailVersionsPanel(detail: detail, openWeb: openWeb)
                    .id("editions")

                if detail.kind == .movie, ReleaseTimeline.hasData(detail) {
                    DetailSection(title: "Release timeline")
                    ReleaseTimeline(detail: detail)
                }
                DetailRailStack(detail: detail)

                DetailTabsView(detail: detail, openWeb: openWeb)
                    .id("tabs")
                    .padding(.top, 6)

                MetadataCredit(provider: detail.resolvedMetadataProvider ?? "tmdb")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 32)
            }
            .padding(.horizontal, Theme.pageGutter)
            .padding(.bottom, 32)
        }
    }

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
