import SwiftUI
import FusionhaKit

/// An "Available to add" result as a grid tile (search + Add mock v10): the
/// clean poster, the title on two lines and the year with the rating under
/// it, and the row's first action as a round button beside the caption
/// (+ to add, person to request). Tapping the poster does what tapping the
/// row does (the preview). Content, not glass.
extension SearchAddRow {
    var tileBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: primary) {
                Color.clear
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay { PosterImage(url: TMDBImage.resized(hit.posterUrl, to: "w342")) }
                    .shelfPosterPlated(radius: 12, ring: picked ? Theme.primary : Theme.txt.opacity(0.08),
                                       ringWidth: picked ? 2.5 : 0.5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle(scale: 0.97))
            .accessibilityLabel(hit.title)
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BrowseInks(page: page).ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        if hit.isTvdbOnly { TvdbLogo(size: 9, label: "TheTVDB only") }
                        Text(tileMeta)
                            .font(.system(size: 11.5))
                            .foregroundStyle(upcoming != nil && hit.tmdb?.voteAverage ?? 0 == 0 ? Theme.miss
                                             : BrowseInks(page: page).muted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                tileAction
            }
            .padding(.top, 7)
            .padding(.horizontal, 1)
        }
    }

    /// "2024 · ★ 7.3", or "Dec 2026" for a title not out yet.
    private var tileMeta: String {
        if let vote = hit.tmdb?.voteAverage, vote > 0 {
            return SearchRowText.meta(year: hit.year, kind: "★ " + String(format: "%.1f", vote))
        }
        if let soon = upcoming { return soon }
        return SearchRowText.meta(year: hit.year, kind: kindName)
    }

    @ViewBuilder
    private var tileAction: some View {
        switch rowActions.first {
        case .add: tileButton("plus", label: "Add", filled: true, action: add)
        case .request: tileButton("person", label: "Request", filled: false, action: request)
        case .open, .none: EmptyView()
        }
    }

    private func tileButton(_ symbol: String, label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(filled ? Theme.onAccent : Theme.txt)
                .frame(width: 26, height: 26)
                .background(filled ? Theme.primary : Theme.panel2, in: Circle())
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
        .padding(.top, -4)
        .padding(.trailing, -4)
        .accessibilityLabel(label)
    }
}

/// A lane's results as a poster grid: as many columns as the Library's grid
/// fits in the same width (three on a phone and the folded Duo).
struct SearchTileGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder var content: Content
    @State private var width: CGFloat = 0

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: gap, alignment: .top), count: count)
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) { content }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .padding(.horizontal, Theme.pageGutter)
            .padding(.bottom, 4)
    }

    // The Library grid's sizing lives in v2; v1 (rows only) keeps three columns.
    #if V2
    private var gap: CGFloat { V2LibraryGrid.columnGap(width: width, sizeClass: sizeClass) }
    private var count: Int { max(V2LibraryColumns.count(for: width), 1) }
    #else
    private var gap: CGFloat { 12 }
    private var count: Int { 3 }
    #endif
}
