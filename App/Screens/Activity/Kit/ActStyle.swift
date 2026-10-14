import SwiftUI
import FusionhaKit

// The web's shared Activity / Wanted primitives (Tabs, histChip, ListSearch,
// SegmentedControl, OverviewStrip, EmptyState, GroupCard, StatusWash,
// InfiniteScrollFooter, BulkBar, toasts), one concern per file in
// Activity/Kit/. Prefixed `Act` so they never collide with the shared
// components.

// MARK: Colours

enum ActColor {
    /// The SegmentedControl group fill.
    static var segTrack: Color { Theme.panel }
    /// The SegmentedControl active text.
    static var segText: Color { Theme.i2 }
}

// MARK: Status wash (StatusWash.module.css)

extension View {
    /// The ambient left-edge tint: `linear-gradient(90deg, mix(c 13%, --card) 0%, --card 42%)`.
    func actWash(_ color: Color?, radius: CGFloat = 14, base: Color = Theme.card, border: Color = Theme.line) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(base)
                .overlay {
                    if let color {
                        LinearGradient(stops: [.init(color: color.opacity(0.13), location: 0),
                                               .init(color: color.opacity(0), location: 0.42)],
                                       startPoint: .leading, endPoint: .trailing)
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    }
                }
        }
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(border))
    }
}

// MARK: Flat-list pieces
//
// Long lists are laid out flat (each row a direct child of the page's lazy
// stack), so the decorations that used to wrap the whole list — the timeline
// thread, the shared card — are drawn per row instead.

/// The 2pt timeline thread behind one row (left 10), inset 12pt at the ends.
struct ActTimelineSegment: View {
    let first: Bool
    let last: Bool
    var leading: CGFloat = 10

    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(width: 2)
            .padding(.top, first ? 12 : 0)
            .padding(.bottom, last ? 12 : 0)
            .padding(.leading, leading)
    }
}

extension View {
    /// One row of a single rounded panel card: rounded ends on the first and
    /// last rows, a hairline between rows, the border only on the outside.
    func actCardSegment(first: Bool, last: Bool, radius: CGFloat = 14) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: first ? radius : 0, bottomLeadingRadius: last ? radius : 0,
                                           bottomTrailingRadius: last ? radius : 0, topTrailingRadius: first ? radius : 0,
                                           style: .continuous)
        return background(Theme.panel, in: shape)
            .overlay {
                shape.strokeBorder(Theme.line)
                    .padding(.top, first ? 0 : -1)
                    .padding(.bottom, last ? 0 : -1)
                    .clipped()
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                if !first { Rectangle().fill(Theme.line).frame(height: 1).allowsHitTesting(false) }
            }
    }
}

// MARK: Poster

enum ActPosterSize {
    case sm, md, lg
    var size: CGSize {
        switch self {
        case .sm: return CGSize(width: 30, height: 45)
        case .md: return CGSize(width: 36, height: 54)
        case .lg: return CGSize(width: 48, height: 72)
        }
    }
    var radius: CGFloat { self == .sm ? 6 : (self == .md ? 7 : 8) }
}

struct ActPoster: View {
    let url: String?
    let title: String
    var size: ActPosterSize = .md

    var body: some View {
        PosterImage(url: TMDBImage.resized(url, to: "w154"))
            .overlay {
                if url == nil {
                    Text(String(title.prefix(1)).uppercased())
                        .font(.system(size: size == .sm ? 11 : 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                }
            }
            .frame(width: size.size.width, height: size.size.height)
            .shelfPoster(radius: size.radius)
            .accessibilityHidden(true)
    }
}

// MARK: Flow layout (wrapping chip rows)

struct ActFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    /// Arrangements per proposed width. Parent stacks probe a child at several
    /// widths (0, ∞, the real one) in every pass, so remembering only the last
    /// width re-measured every chip on nearly every call.
    struct Cache {
        var byWidth: [CGFloat: Arrangement] = [:]
    }

    struct Arrangement {
        var rows: [Row] = []
        var sizes: [CGSize] = []
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) { cache.byWidth.removeAll(keepingCapacity: true) }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        PerfCount.hit("ActFlow.sizeThatFits")
        let rows = arrangement(width: proposal.width ?? .infinity, subviews: subviews, cache: &cache).rows
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        let natural = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? natural, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let arranged = arrangement(width: bounds.width, subviews: subviews, cache: &cache)
        var y = bounds.minY
        for row in arranged.rows {
            var x = alignment == .trailing ? bounds.maxX - row.width : bounds.minX
            for index in row.indices {
                let size = arranged.sizes[index]
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    /// Natural size, but a subview wider than the line wraps to the line width instead of overflowing.
    private func measure(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        guard width.isFinite, natural.width > width else { return natural }
        return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    private func arrangement(width: CGFloat, subviews: Subviews, cache: inout Cache) -> Arrangement {
        if let hit = cache.byWidth[width], hit.sizes.count == subviews.count { return hit }
        PerfCount.hit("ActFlow.arrange")
        var rows: [Row] = []
        var sizes: [CGSize] = []
        sizes.reserveCapacity(subviews.count)
        var row = Row()
        for index in subviews.indices {
            let size = measure(subviews[index], width: width)
            sizes.append(size)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        let arranged = Arrangement(rows: rows, sizes: sizes)
        if cache.byWidth.count > 8 { cache.byWidth.removeAll(keepingCapacity: true) }
        cache.byWidth[width] = arranged
        return arranged
    }
}
