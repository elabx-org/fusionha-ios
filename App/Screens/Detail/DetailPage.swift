import SwiftUI
import FusionhaKit

/// The hero art repeated behind everything: blurred, saturated and darkened,
/// under a `--bg` scrim (MobileDetailFlyout `.ambient`). Content, not glass.
struct AmbientBackdrop: View {
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

/// The scrolling page body (MobileDetailFlyout `.body`): setup strip,
/// overview, Item actions + its "applies to" echo, Versions, the release
/// timeline, the rails and the tabs.
struct DetailPage: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let close: () -> Void
    let openWeb: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailHero(detail: detail, close: close)

            VStack(alignment: .leading, spacing: 0) {
                if let setup = model.setupProgress.activeSetup(for: detail.id) {
                    SetupStepStrip(setup: setup)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
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
                    .id("actions")
                ItemActionsRail(detail: detail, openWeb: openWeb)
                appliesTo

                DetailSection(title: "Versions")
                    .id("editions")
                DetailVersionsPanel(detail: detail, openWeb: openWeb)

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

    /// The rail's read-only `applies to {all versions | tier}` echo (the web's
    /// `.railRow` wraps it under the full-width rail with a 12px gap).
    private var appliesTo: some View {
        (Text("applies to ").foregroundColor(Theme.dim)
            + Text(store.actsOnLabel).font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundColor(Theme.txt))
            .font(.system(size: 11.5))
            .padding(.top, 12)
            .contentTransition(.opacity)
            .detailAnimation(.easeInOut(duration: 0.2), value: store.actsOnLabel)
    }
}
