import SwiftUI
import FusionhaKit

/// The Preview page under its hero: the overview, the add/request action,
/// seasons, trailer, "More like this" and cast. v1 draws it on the ambient
/// bleed in its own tokens; v2 (`\.browseLook`, look pass family 5) on the
/// art's page ground in the palette's inks, seasons on W1 cards, sentence
/// case headings and the glass primary.
struct PreviewBody: View {
    @Environment(\.browseLook) private var look
    @Environment(\.pagePalette) private var page
    let detail: MediaPreviewDetail
    let canAdd: Bool
    let canRequest: Bool
    let continueAdding: Bool
    let onAdd: (MediaSearchResult) -> Void
    let onRequest: (MediaSearchResult) -> Void
    let onOpenLibrary: (Int) -> Void

    private var inks: BrowseInks { BrowseInks(page: page) }

    var body: some View {
        let d = detail
        VStack(alignment: .leading, spacing: 0) {
            if let overview = d.overview, !overview.isEmpty {
                Text(overview)
                    .font(.system(size: look == nil ? 14 : 15))
                    .lineSpacing(look == nil ? 14 * 0.55 - 3 : 3)
                    .foregroundStyle(look == nil ? Theme.txt.opacity(0.9) : inks.ink)
                    .shadow(color: .black.opacity(look == nil ? 0.4 : 0), radius: 6)
                    .readableWidth()
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            PreviewActions(detail: d, canAdd: canAdd, canRequest: canRequest, continueAdding: continueAdding,
                           onAdd: onAdd, onRequest: onRequest, onOpenLibrary: onOpenLibrary)
                .padding(.top, 14)
            if d.kind == .series, let seasons = d.seasons, !seasons.isEmpty {
                section("Seasons") { seasonGrid(seasons) }
            }
            if let key = d.trailerKey, !key.isEmpty {
                section("Trailer") { PreviewTrailer(key: key) }
            }
            if let similar = d.similar, !similar.isEmpty {
                section("More like this") { PreviewSimilarRail(cards: similar) }
            }
            if let cast = d.cast, !cast.isEmpty {
                castRail(cast)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 24)
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: look == nil ? 14 : 12) {
            Text(title)
                .font(.system(size: look == nil ? 15 : 20, weight: .bold))
                .foregroundStyle(inks.ink)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(.top, look == nil ? 30 : 26)
    }

    private func seasonGrid(_ seasons: [PreviewSeason]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(seasons) { season in
                VStack(alignment: .leading, spacing: 4) {
                    Text(season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(inks.ink)
                    Text(season.episodeCount == 1 ? "1 episode" : "\(season.episodeCount) episodes")
                        .font(.system(size: 12.5)).foregroundStyle(inks.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .modifier(PreviewSeasonCard(look: look))
            }
        }
    }

    private func castRail(_ cast: [CastMember]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if look == nil {
                Text("CAST").font(.system(size: 12, weight: .bold)).tracking(0.72).foregroundStyle(Theme.mut)
            } else {
                Text("Cast").font(.system(size: 20, weight: .bold)).foregroundStyle(inks.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(Array(cast.enumerated()), id: \.offset) { _, member in CastCard(member: member) }
                }
            }
            .scrollClipDisabled()
        }
        .padding(.top, 26)
    }
}

/// A season tile's card: v1's panel, v2's W1 card.
private struct PreviewSeasonCard: ViewModifier {
    let look: BrowseLookOverride?

    func body(content: Content) -> some View {
        if look != nil {
            content.browseCard(look, radius: 18)
        } else {
            content.panel(Theme.panel2, radius: 12)
        }
    }
}

/// The page's one action: Open in library for a title you have, else Add
/// to library (the Add sheet on its configure step), else Request.
struct PreviewActions: View {
    @Environment(\.browseLook) private var look
    @Environment(\.pagePalette) private var page
    @Environment(AppModel.self) private var model
    let detail: MediaPreviewDetail
    let canAdd: Bool
    let canRequest: Bool
    let continueAdding: Bool
    let onAdd: (MediaSearchResult) -> Void
    let onRequest: (MediaSearchResult) -> Void
    let onOpenLibrary: (Int) -> Void

    var body: some View {
        let d = detail
        if d.inLibrary {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let look {
                        if let item = d.libraryItemId.flatMap({ id in model.library.first { $0.id == id } }) {
                            look.tickets(item)
                        }
                    } else {
                        PosterStatusBadge(kind: .inLibrary)
                    }
                    Text("Already in your library")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                }
                if let id = d.libraryItemId {
                    primary { Text("Open in library") } action: { onOpenLibrary(id) }
                }
            }
        } else if canAdd {
            // The Add sheet opens on its configure step for this title.
            primary {
                if continueAdding {
                    Text("Continue adding")
                } else {
                    Label("Add to library", systemImage: "plus")
                }
            } action: { onAdd(d.asSearchResult) }
        } else if canRequest {
            primary { Text("Request") } action: { onRequest(d.asSearchResult) }
        }
    }

    /// v1's Discover primary, or v2's accent glass capsule.
    @ViewBuilder
    private func primary<L: View>(@ViewBuilder _ label: () -> L, action: @escaping () -> Void) -> some View {
        if look != nil {
            Button(action: action, label: label)
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(Theme.primary)
        } else {
            Button(action: action, label: label)
                .buttonStyle(.discover(.primary))
        }
    }
}
