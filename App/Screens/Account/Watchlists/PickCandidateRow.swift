import SwiftUI
import FusionhaKit

/// One TMDB candidate in the pick (web `PickCandidates`): a small clean
/// poster, title and year, kind, a line of overview; picked shows the check.
struct PickCandidateRow: View {
    let result: MediaSearchResult
    let picked: Bool
    let pick: () -> Void

    var body: some View {
        Button(action: pick) {
            HStack(spacing: 12) {
                PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w154"))
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.year.map { "\(result.title) (\(String($0)))" } ?? result.title)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt).lineLimit(2)
                    Text(result.kind == .movie ? "Movie" : "Series").font(.caption).foregroundStyle(Theme.mut)
                    if let overview = result.overview, !overview.isEmpty {
                        Text(overview).font(.caption).foregroundStyle(Theme.dim).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(picked ? Theme.i2 : Theme.dim)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(picked ? .isSelected : [])
    }
}
