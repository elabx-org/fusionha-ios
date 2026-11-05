import SwiftUI
import FusionhaKit

/// The v2 title page's body (mocks browse.js `titlePhone`, browse-title.js
/// `moviePhone`): the hero, then on the art-palette ground the overview,
/// the version cards, the actions, Needs you (only when something is held),
/// Next up (series), the release timeline (movies) and the tabs. The setup
/// strip and the request strip are v1's, as on the v1 page.
struct V2TitlePage: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    /// The column's width: narrow columns use the smaller cards.
    var width: CGFloat = 0
    @State private var overviewOpen = false

    private var gutter: CGFloat { width >= 560 ? 24 : 20 }
    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        let versions = V2TitleVersion.all(store, detail: detail)
        let needs = V2TitleNeed.all(store: store, detail: detail)
        VStack(alignment: .leading, spacing: 0) {
            V2TitleHero(detail: detail)
            VStack(alignment: .leading, spacing: 0) {
                if let setup = model.setupProgress.activeSetup(for: detail.id) {
                    SetupStepStrip(setup: setup)
                        .padding(.bottom, 10)
                }
                if !detail.isSeries {
                    // The movie's credit opens the page (browse-title.js `moviePhone`);
                    // the alt title beside it waits on the API.
                    credit.font(.system(size: 12, weight: .semibold))
                }
                overview
                    .padding(.top, detail.isSeries ? 0 : 10)
                if !versions.isEmpty {
                    V2TitleVersionStrip(versions: versions, small: width < 400)
                        .padding(.top, 14)
                }
                V2TitleActionRow(detail: detail)
                    .padding(.top, 14)
                ForEach(needs) { need in
                    V2TitleNeedsYouCard(item: need) { review(need) }
                        .padding(.top, need.id == needs.first?.id ? 20 : 10)
                }
                if let next = V2TitleNextUp(detail: detail, store: store) {
                    V2TitleNextUpCard(detail: detail, next: next)
                        .padding(.top, 22)
                }
                if detail.kind == .movie, ReleaseTimeline.hasData(detail) {
                    V2ReleaseTimeline(detail: detail)
                        .padding(.top, 18)
                }
                DetailRequestsStrip(itemId: detail.id)
                    .padding(.top, 14)
                V2TitleTabs(detail: detail)
                    .padding(.top, detail.isSeries ? 22 : 20)
                if detail.isSeries {
                    credit.font(.system(size: 13)).padding(.top, 32)
                }
            }
            .padding(.horizontal, gutter)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .foregroundStyle(ink)
    }

    private var credit: some View {
        MetadataCredit(provider: detail.resolvedMetadataProvider ?? "tmdb")
            .foregroundStyle(muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The overview, three lines with More (the mock's `ovw`).
    @ViewBuilder
    private var overview: some View {
        if let text = detail.overview, !text.isEmpty {
            Button { overviewOpen.toggle() } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.system(size: 14.5))
                        .lineSpacing(3)
                        .foregroundStyle(ink.opacity(0.92))
                        .lineLimit(overviewOpen ? nil : 3)
                        .multilineTextAlignment(.leading)
                    if !overviewOpen {
                        Text("More").font(.system(size: 14.5, weight: .bold)).foregroundStyle(ink)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .readableWidth()
            .accessibilityHint(overviewOpen ? "" : "Shows the whole overview")
        }
    }

    private func review(_ need: V2TitleNeed) {
        switch need.target {
        case .queue(let id):
            model.openInQueue(downloadId: id)
        case .files(let edition):
            store.scope = DetailScope(tier: edition.tier.rawValue, version: edition.versionKey)
            store.tab = .files
        }
    }
}
