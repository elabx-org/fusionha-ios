import SwiftUI
import FusionhaKit

/// The shared "a key is missing" notice (web `KeyMissingNotice`): an amber
/// wash in place of a feature that needs a TMDB or TVDB key.
struct MetadataKeyNotice: View {
    let provider: String
    let feature: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "key")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.miss)
            (Text("\(feature) needs a \(provider == "tvdb" ? "TVDB" : "TMDB") key (free) — ")
             + Text("add one in Settings › Metadata").fontWeight(.semibold).foregroundColor(Theme.txt)
             + Text("."))
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.miss.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Step 1 pieces

func kindName(_ result: MediaSearchResult) -> String {
    result.isAnime ? "Anime" : (result.kind == .movie ? "Movie" : "Series")
}

/// A grid tile: 2:3 art, glass kind chip, "In library" badge or the + / eye
/// buttons, then title and "YYYY · Kind".
struct AddTile: View {
    let result: MediaSearchResult
    let pick: () -> Void
    let preview: () -> Void
    /// The poster is the zoom source for the eye's preview push.
    var zoom: Namespace.ID?

    private var subline: String {
        var parts: [String] = []
        if let year = result.year { parts.append(String(year)) }
        parts.append(kindName(result))
        if result.inLibrary { parts.append("In library") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            poster
                .overlay(alignment: .topLeading) {
                    Image(systemName: result.kind == .movie && !result.isAnime ? "film" : "tv")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(result.isAnime ? Theme.anime : Theme.txt)
                        .frame(width: 27, height: 27)
                        .glassEffect(.regular, in: Circle())
                        .padding(6)
                }
                .overlay(alignment: .topTrailing) {
                    if result.inLibrary {
                        Text("In library")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Theme.done)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.done.opacity(0.45)))
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !result.inLibrary {
                        HStack(spacing: 5) {
                            Button(action: preview) {
                                Image(systemName: "eye")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.txt)
                                    .frame(width: 30, height: 30)
                                    .glassEffect(.regular.interactive(), in: Circle())
                            }
                            .accessibilityLabel("Preview")
                            Button(action: pick) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.onPrimary)
                                    .frame(width: 30, height: 30)
                                    .background(Theme.fusion, in: Circle())
                            }
                            .accessibilityLabel("Add \(result.title)")
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.9))
                        .padding(6)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(TitleYear.display(result.title, nil).title)
                    .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text(subline)
                    .font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: pick)
    }

    @ViewBuilder
    private var poster: some View {
        let art = PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w500"))
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
        if let zoom {
            art.matchedTransitionSource(id: "tile-\(result.id)", in: zoom)
        } else {
            art
        }
    }
}

/// A list row: 38×52 thumb, title + year, "Kind · via TMDB", Add / Open ↗.
struct AddListRow: View {
    let result: MediaSearchResult
    let pick: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w154"))
                .frame(width: 38, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                let shown = TitleYear.display(result.title, result.year)
                (Text(shown.title).foregroundStyle(Theme.txt)
                    + Text(shown.year.map { "  " + String($0) } ?? "").foregroundStyle(Theme.mut).font(.system(size: 13)))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("\(kindName(result)) · via TMDB").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 6)
            Button(action: pick) {
                if result.inLibrary {
                    Text("Open ↗").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
                } else {
                    Text("Add")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Theme.onPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(Theme.fusion, in: Capsule())
                }
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(8)
        .panel(Theme.card, radius: 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: pick)
    }
}

/// A TVDB row: thumb, title + year, a two-line overview, "Add via TVDB".
struct TvdbRow: View {
    let result: TvdbSearchResult
    let pick: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            PosterImage(url: result.imageUrl.flatMap(URL.init(string:)))
                .frame(width: 38, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                let shown = TitleYear.display(result.title, result.year)
                (Text(shown.title).foregroundStyle(Theme.txt)
                    + Text(shown.year.map { "  " + String($0) } ?? "").foregroundStyle(Theme.mut).font(.system(size: 13)))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("Series · via TVDB").font(.system(size: 12)).foregroundStyle(Theme.mut)
                if let overview = result.overview, !overview.isEmpty {
                    Text(overview).font(.system(size: 12)).foregroundStyle(Theme.dim).lineLimit(2)
                }
            }
            Spacer(minLength: 6)
            Button(action: pick) {
                if result.inLibrary == true {
                    Text("Open ↗").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
                } else {
                    Text("Add via TVDB")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color(hex: 0x4FB862), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(8)
        .panel(Theme.card, radius: 12)
    }
}
