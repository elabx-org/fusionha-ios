import SwiftUI
import FusionhaKit

/// The address preview (web `Recognised` + `FeedPreview`): the site chip,
/// Recognised, the owner and a link to the list; then the title, the facts,
/// the movie / series mix bar and a strip of six clean posters (an in-library
/// title wears a check badge beside the art, never text on it).
struct FeedPreviewSection: View {
    let preview: LbSourcePreview
    let url: String
    private static let strip = 6

    var body: some View {
        Section {
            recognised
            VStack(alignment: .leading, spacing: 8) {
                Text(preview.title ?? "@\(preview.owner ?? "")").font(.headline).foregroundStyle(Theme.txt)
                facts
                if let mix = preview.mix, mix.total > 0 { MixBar(mix: mix) }
            }
            PosterStrip(items: preview.items.prefix(Self.strip).map { PosterStrip.Item($0) })
        } footer: {
            Text(FeedCopy.sample)
        }
    }

    private var recognised: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { recognisedParts }
            VStack(alignment: .leading, spacing: 6) { recognisedParts }
        }
    }

    @ViewBuilder private var recognisedParts: some View {
        ProviderChip(provider: preview.site, text: "\(preview.site.word) · \(FeedCopy.kindWord(preview.kind))")
        Label(FeedCopy.recognised, systemImage: "checkmark")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.text(.done))
        if let owner = preview.owner {
            Text(FeedCopy.by(owner)).font(.caption).foregroundStyle(Theme.mut)
        }
        if let link = URL(string: url.hasPrefix("http") ? url : "https://\(url)") {
            Link(FeedCopy.openOn(preview.site.word), destination: link).font(.caption.weight(.semibold))
        }
    }

    private var facts: some View {
        let total = preview.itemCount ?? preview.items.count
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { factParts(total) }
            VStack(alignment: .leading, spacing: 3) { factParts(total) }
        }
        .font(.subheadline)
        .foregroundStyle(Theme.mut)
    }

    @ViewBuilder private func factParts(_ total: Int) -> some View {
        Text("\(Text("\(total)").bold().foregroundStyle(Theme.txt)) \(FeedCopy.titles)")
        if let mix = preview.mix {
            Text("\(Text("\(mix.movies)").bold().foregroundStyle(Theme.txt)) \(FeedCopy.movies) · \(Text("\(mix.series)").bold().foregroundStyle(Theme.txt)) \(FeedCopy.series)")
        }
        if let own = preview.inLibraryCount, own > 0 {
            Text("\(Text("\(own)").bold()) \(FeedCopy.inLibrary)").foregroundStyle(Theme.text(.done))
        }
    }
}

/// The movie / series split as one thin bar (movies in the movie hue).
struct MixBar: View {
    let mix: PreviewMix

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                Capsule().fill(Theme.kindMovie).frame(width: max(0, geo.size.width * mix.movieShare - 1))
                Capsule().fill(Theme.kindSeries)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel(FeedCopy.mixLabel(mix.movies, mix.series))
    }
}

/// A row of small clean posters; a title with no art shows its name on the
/// placeholder tile (there is no art to keep clean). An in-library title gets
/// a check under its poster, never on the art.
struct PosterStrip: View {
    struct Item: Hashable {
        let title: String
        let year: Int?
        let posterUrl: String?
        let inLibrary: Bool
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    poster(item)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.done)
                        .opacity(item.inLibrary ? 1 : 0)
                }
                .frame(maxWidth: 72)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(item))
            }
        }
    }

    @ViewBuilder private func poster(_ item: Item) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        if let url = TMDBImage.resized(item.posterUrl, to: "w154") {
            PosterImage(url: url)
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(shape)
        } else {
            shape.fill(Theme.panel2)
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay(Text(item.title).font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center).padding(4))
        }
    }

    private func label(_ item: Item) -> String {
        let base = item.year.map { "\(item.title) (\($0))" } ?? item.title
        return item.inLibrary ? "\(base), \(FeedCopy.inLibrary)" : base
    }
}

extension PosterStrip.Item {
    init(_ item: LbPreviewItem) {
        self.init(title: item.title, year: item.year, posterUrl: item.posterUrl, inLibrary: item.inLibrary)
    }

    init(_ item: ImportListPreviewItem) {
        self.init(title: item.title, year: item.year, posterUrl: item.posterUrl, inLibrary: item.inLibrary)
    }
}
