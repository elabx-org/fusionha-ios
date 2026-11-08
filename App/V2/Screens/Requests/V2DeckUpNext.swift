import SwiftUI
import FusionhaKit

/// "Up next" under the folded Duo's deck card (mock requests.js
/// `inboxOuter`): the heading with "4 more · all from Letterboxd", then a
/// rail of the clean posters still waiting after the top card. A poster
/// opens that request's decision card (Details).
struct V2DeckUpNext: View {
    /// The waiting requests after the top card, in deck order.
    let rest: [MediaRequest]
    let onOpen: (MediaRequest) -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Up next")
                    .font(.system(size: 21, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .accessibilityAddTraits(.isHeader)
                Text(Self.summary(rest))
                    .font(.subheadline)
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(rest) { request in
                        Button { onOpen(request) } label: {
                            PosterImage(url: TMDBImage.resized(request.poster, to: "w185"), size: CGSize(width: 74, height: 111))
                                .frame(width: 74, height: 111)
                                .shelfPoster(radius: 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(request.title ?? "TMDB #\(request.tmdbId)")
                        .accessibilityHint("Opens its decision")
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    /// "4 more", plus "· all from Letterboxd" when they share one source.
    static func summary(_ rest: [MediaRequest]) -> String {
        let count = "\(rest.count) more"
        let words = Set(rest.map { RequestOrigin.word($0.source) })
        guard rest.count > 1, words.count == 1, let word = words.first, word != "Manual" else { return count }
        return "\(count) · all from \(word)"
    }
}
