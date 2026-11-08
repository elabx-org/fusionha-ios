import SwiftUI
import FusionhaKit

/// What the title says about itself above its tabs (mocks browse.js
/// `titlePhone`, browse-title.js `moviePhone` and `tabWide`'s summary): the
/// setup strip, the movie's credit, the overview (three lines, More), the
/// version cards, the actions, Needs you (only when something is held),
/// Next up (series), the release timeline (movies) and the request strip.
/// The one-column page runs it under the hero; the title filling the flat
/// open Duo runs it as its left column (`V2TitleWidePage`).
struct V2TitleSummary: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    /// Narrow columns: the smaller version cards.
    var small = false
    /// The wide page's left column: Monitored drops to its own line (mock
    /// `tabWide`), so the row never runs past the column.
    var stacksActions = false
    @State private var overviewOpen = false

    private var ink: Color { page?.ink ?? Theme.txt }
    var body: some View {
        let versions = V2TitleVersion.all(store, detail: detail)
        let needs = V2TitleNeed.all(store: store, detail: detail)
        VStack(alignment: .leading, spacing: 0) {
            if let setup = model.setupProgress.activeSetup(for: detail.id) {
                V2SetupStrip(setup: setup)
                    .padding(.bottom, 10)
            }
            if !detail.isSeries {
                // The movie's credit opens the page (browse-title.js `moviePhone`);
                // the alt title beside it waits on the API.
                V2TitleCredit(detail: detail).font(.system(size: 12, weight: .semibold))
            }
            overview
                .padding(.top, detail.isSeries ? 0 : 10)
            if !versions.isEmpty {
                V2TitleVersionStrip(versions: versions, small: small)
                    .padding(.top, 14)
            }
            V2TitleActionRow(detail: detail, stacked: stacksActions)
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
        }
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
            // Straight to the files that need you, already selected, so
            // Replace or Delete is one tap (it used to only switch tabs,
            // which did nothing when Files was already showing).
            store.scope = DetailScope(tier: edition.tier.rawValue, version: edition.versionKey)
            store.tab = .files
            store.manageFiles = ManageFilesTarget(versionIds: [edition.id], season: nil, problems: true)
        }
    }
}

/// "Metadata via TMDB" in the page's muted ink.
struct V2TitleCredit: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail

    var body: some View {
        MetadataCredit(provider: detail.resolvedMetadataProvider ?? "tmdb")
            .foregroundStyle(page?.inkMuted ?? Theme.mut)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
