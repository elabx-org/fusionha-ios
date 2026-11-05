import SwiftUI
import FusionhaKit

/// The Overview tab in v2 (browse-title.js `movieOverview`): the genres, the
/// trailer card, the cast rail, the collection (v1's rail, it links into the
/// Collection tab) and More like this (v1's rail, it opens Preview). Section
/// heads in the page ink; the art stays clean.
struct V2TitleOverviewTab: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail

    private var genres: [String] { detail.genres ?? [] }
    private var cast: [CastMember] { detail.cast ?? [] }
    private var similar: [SimilarTitle] { detail.similar ?? [] }
    private var trailer: String? { detail.trailerKey.flatMap { $0.isEmpty ? nil : $0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !genres.isEmpty {
                V2GenreRow(genres: genres)
            }
            if let trailer {
                V2TrailerCard(key: trailer, art: detail.backdropUrl)
                    .padding(.top, genres.isEmpty ? 0 : 16)
            }
            if !cast.isEmpty {
                V2TitleSectionHead(title: "Cast", detail: "\(cast.count) people")
                V2CastRail(cast: cast)
                    .padding(.top, 12)
            }
            if detail.collection != nil, let collection = store.collection {
                DetailCollectionRail(collection: collection)
                    .padding(.top, 22)
            }
            if !similar.isEmpty {
                V2TitleSectionHead(title: "More like this", detail: "from TMDB")
                DetailSimilarRail(similar: similar)
                    .padding(.top, 10)
            }
            if genres.isEmpty && trailer == nil && cast.isEmpty && similar.isEmpty && store.collection == nil {
                EmptyBox(message: "No trailer, cast or similar titles for this one yet.")
            }
        }
    }
}

/// "Cast … 234 people" (kit `.secl`): a 20pt head in the page ink, its
/// detail muted on the trailing edge.
struct V2TitleSectionHead: View {
    let title: String
    var detail: String?
    var top: CGFloat = 22
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
            }
        }
        .padding(.top, top)
    }
}

/// The genres as flat capsules in the page ink (mock `.genres span`).
struct V2GenreRow: View {
    let genres: [String]
    @Environment(\.pagePalette) private var page

    var body: some View {
        FlowRow(spacing: 6) {
            ForEach(genres, id: \.self) { genre in
                Text(genre)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background((page?.ink ?? Theme.txt).opacity(0.09), in: Capsule())
            }
        }
    }
}

/// The trailer card (mock `.trailer`): the title's art in 2.4:1 with a glass
/// play button; it opens YouTube.
struct V2TrailerCard: View {
    let key: String
    let art: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: "https://www.youtube.com/watch?v=\(key)") { openURL(url) }
        } label: {
            Color.clear
                .aspectRatio(2.4, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    PosterImage(url: art.flatMap { TMDBImage.resized($0, to: "w780") }
                        ?? URL(string: "https://img.youtube.com/vi/\(key)/hqdefault.jpg"))
                }
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Official trailer").font(.system(size: 13, weight: .semibold))
                        Text("YouTube").font(.system(size: 11.5, weight: .medium)).opacity(0.8)
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 12)
                    .padding(.bottom, 10)
                }
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.98))
        .accessibilityLabel("Play trailer")
    }
}

/// The cast: round photos, the name and the part, in the page inks.
struct V2CastRail: View {
    let cast: [CastMember]
    @Environment(\.pagePalette) private var page

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(cast.indices, id: \.self) { i in
                    let person = cast[i]
                    VStack(spacing: 4) {
                        PosterImage(url: TMDBImage.resized(person.profileUrl, to: "h632"))
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                        Text(person.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(page?.ink ?? Theme.txt)
                            .padding(.top, 3)
                        if let character = person.character {
                            Text(character)
                                .font(.system(size: 11))
                                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        }
                    }
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(width: 74)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}
