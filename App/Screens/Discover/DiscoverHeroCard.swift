import SwiftUI
import FusionhaKit

/// One Discover hero card (mock discover.js `hero`): the title's backdrop,
/// a dark foot, "TRENDING #N THIS WEEK", the title, "year · kind · ★ rating",
/// then what you own (its HD and 4K tickets) or "Not in your library" with
/// Add (or Request). Content, not glass; always on dark. A tap opens the
/// owned title, else the preview; Add opens the Add sheet on it.
struct DiscoverHeroCard: View {
    let result: MediaSearchResult
    let rank: Int
    let size: CGSize
    let canAdd: Bool
    let canRequest: Bool
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @Environment(\.browseLook) private var look

    private var owned: MediaItem? { model.ownedItem(for: result) }
    private var radius: CGFloat { 24 }

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .bottomLeading) {
                Color(white: 0.1)
                PosterImage(url: TMDBImage.resized(result.backdropUrl ?? result.posterUrl, to: "w780"), size: size)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                LinearGradient(stops: [.init(color: .black.opacity(0), location: 0.3),
                                       .init(color: .black.opacity(0.82), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                footer
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.08)))
            .shadow(color: .black.opacity(0.28), radius: 16, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .environment(\.colorScheme, .dark)
        .badgeInk(.onArt)
        .contextMenu {
            Button("Preview", systemImage: "eye") { store.preview = PreviewRoute(result) }
            if owned == nil && canAdd {
                Button("Add to library", systemImage: "plus", action: add)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trending #\(rank) this week")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.78))
            Text(result.title)
                .font(.system(size: size.width < 300 ? 21 : 24, weight: .bold))
                .tracking(-0.3)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
            meta
            status.padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var meta: some View {
        HStack(spacing: 5) {
            DiscoverKindGlyph(kind: result.kind, isAnime: result.isAnime, size: 12, color: .white.opacity(0.8))
            Text(metaText)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.84))
        .lineLimit(1)
    }

    private var metaText: String {
        let kind = result.isAnime ? "Anime" : result.kind == .movie ? "Movie" : "Series"
        let rating = result.voteAverage.flatMap { $0 > 0 ? "★ \($0.formatted(.number.precision(.fractionLength(1))))" : nil }
        return [result.displayYear.map(String.init), kind, rating].compactMap { $0 }.joined(separator: " · ")
    }

    @ViewBuilder
    private var status: some View {
        if let owned, let look {
            look.tickets(owned)
        } else {
            HStack(spacing: 10) {
                Text(result.inLibrary ? "In your library" : "Not in your library")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if !result.inLibrary && canAdd {
                    Button(action: add) {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(Theme.primary, in: Capsule())
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.94))
                    .accessibilityLabel("Add \(result.title)")
                }
            }
        }
    }

    private func open() {
        if let owned, !model.requestScoped {
            model.open(owned.id)
        } else if canAdd || result.inLibrary {
            store.preview = PreviewRoute(result)
        } else if canRequest {
            store.requestPick = result
        }
    }

    private func add() {
        model.openAdd(result, providerOverride: DiscoverSession.shared.providerOverride)
    }
}
