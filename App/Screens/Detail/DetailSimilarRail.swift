import SwiftUI
import FusionhaKit

/// "More like this" on a library title's page (web `SimilarRail`): each card
/// opens that title's Preview (`/preview/{kind}/{tmdbId}`), which offers Add,
/// or opens the library item when the title is already in the library.
struct DetailSimilarRail: View {
    let similar: [SimilarTitle]
    @Environment(AppModel.self) private var model
    @Environment(\.posterRail) private var rail
    @State private var preview: PreviewRoute?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: rail.spacing) {
                ForEach(Array(similar.enumerated()), id: \.offset) { index, title in
                    card(title)
                        .containerRelativeFrame(.horizontal) { width, _ in rail.cardWidth(width) }
                        .detailReveal(delay: Double(min(index, 8)) * 0.04, y: 8, duration: 0.4)
                }
            }
        }
        .scrollClipDisabled()
        .duoPageSheet(item: $preview) { route in
            PreviewSheet(route: route, onOpenLibrary: openLibrary)
        }
    }

    @ViewBuilder
    private func card(_ title: SimilarTitle) -> some View {
        if let route = Self.route(title) {
            Button { preview = route } label: { cardLabel(title) }
                .buttonStyle(DiscoverPressStyle())
                .accessibilityLabel(title.inLibrary == true ? "View \(title.title ?? "")" : "Add \(title.title ?? "")")
        } else {
            cardLabel(title)
        }
    }

    /// Web `.card`: a 2:3 lit shelf poster (no badge on the art), then the
    /// title and "year · In library".
    private func cardLabel(_ title: SimilarTitle) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay { DiscoverArt(url: TMDBImage.resized(title.posterUrl, to: "w500")) }
                .shelfPoster(radius: rail.radius)
                .padding(.bottom, 8)
            Text(title.title ?? "").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            // Nothing on the art: "in library" sits in the caption line.
            HStack(spacing: 4) {
                if let year = title.year {
                    Text(verbatim: "\(year)")
                }
                if title.inLibrary == true {
                    if title.year != nil { Text("·") }
                    Text("In library").foregroundStyle(Theme.txt)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
        }
        .contentShape(Rectangle())
    }

    static func route(_ title: SimilarTitle) -> PreviewRoute? {
        guard let tmdbId = title.tmdbId else { return nil }
        let kind = title.kind.flatMap(PreviewKind.init(rawValue:)) ?? .movie
        return PreviewRoute(kind: kind, tmdbId: tmdbId)
    }

    /// The preview's "open in library": close it, then switch this page to that title.
    private func openLibrary(_ id: Int) {
        preview = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            model.open(id)
        }
    }
}
