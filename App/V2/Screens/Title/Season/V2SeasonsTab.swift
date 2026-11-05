import SwiftUI
import FusionhaKit

/// The series' Seasons tab in v2 (mock browse.js `seasonCard`, `head:
/// false`): v1's renumbering banner when numbering is off (the check itself
/// is in the More menu), then one W1 card per season, newest first and
/// Specials last. A card pushes its season page (`V2TitleRoute.season`).
struct V2SeasonsTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    var compact = false

    private var muted: Color { page?.inkMuted ?? Theme.mut }

    /// The running `tree` step's source while the season list is still empty (v1's rule).
    private var waitingSource: String? {
        guard let setup = model.setupProgress.activeSetup(for: detail.id),
              let tree = setup.steps.first(where: { $0.key == "tree" }),
              tree.status == .running else { return nil }
        return tree.source ?? "the provider"
    }

    var body: some View {
        let seasons = detail.seasonsNewestFirst
        let editions = detail.orderedEditions
        VStack(alignment: .leading, spacing: 10) {
            if detail.numberingMismatch == true { numberingBanner }
            if seasons.isEmpty {
                Text(waitingSource.map { "Waiting for seasons from \($0)…" } ?? "No seasons yet for this title.")
                    .font(.system(size: 14))
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background { ModuleSurface(radius: 18) }
            }
            ForEach(seasons) { season in
                NavigationLink(value: V2TitleRoute.season(season.seasonNumber)) {
                    V2SeasonCard(detail: detail, season: season,
                                 facts: V2SeasonFacts(season: season, editions: editions), compact: compact)
                }
                .buttonStyle(PressScaleStyle(scale: 0.98))
            }
        }
    }

    private var numberingBanner: some View {
        Button {
            store.showingNumbering = true
        } label: {
            Label(detail.episodeNumberingSource == "tvmaze"
                  ? "Episode numbering may be off vs TVmaze. Review"
                  : "TheTVDB renumbered this show. Review",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.stuck)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background { ModuleSurface(radius: 16) }
        }
        .buttonStyle(.plain)
    }
}
