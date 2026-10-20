import SwiftUI
import FusionhaKit

/// The wide Board (web `RequestsBoard`, desktop): the five stages as
/// fixed-height columns side by side, at least 220 wide each and stretched
/// across the pane; when five don't fit the row scrolls sideways and snaps
/// to a column, as the web does. Each column scrolls on its own (DU3).
///
/// When the iPhone Duo's fold runs through the Board (flat open included),
/// the columns page instead: each page fills the space before the fold's
/// gutter, so at every resting position a page ends before the fold and the
/// next starts after it, and no stage straddles it (`FoldColumns.pages`).
struct BoardColumnsView<Row: View>: View {
    let board: BoardModel
    /// A stage's rows (Pending without those the Undo is holding).
    let rows: (RequestBoard.Column) -> [MediaRequest]
    let onRetry: () -> Void
    let onLoadMore: (RequestBoard.Column) -> Void
    let onOpenHistory: (HistoryFilter) -> Void
    @ViewBuilder let row: (MediaRequest, RequestBoard.Column) -> Row

    private var columns: [RequestBoard.Column] { RequestBoard.Column.allCases }

    var body: some View {
        GeometryReader { proxy in
            let plan = BoardPlan(proxy, count: columns.count)
            ScrollView(.horizontal) {
                // One layout in every pose, so the stages keep their state
                // ("Show all", scroll) when the fold comes and goes (DC3).
                TrackLayout(tracks: plan.tracks, width: plan.width, height: proxy.size.height) {
                    ForEach(columns, id: \.self) { column in stage(column) }
                }
            }
            .scrollTargetBehavior(StrideScrollTarget(stride: plan.stride, maxOffset: plan.maxOffset))
            .scrollIndicators(.hidden)
        }
    }

    private func stage(_ column: RequestBoard.Column) -> some View {
        BoardColumnView(column: column, items: rows(column), board: board,
                        onRetry: onRetry, onLoadMore: { onLoadMore(column) },
                        onOpenHistory: onOpenHistory) { r in row(r, column) }
    }
}

/// Where the stages go: the web's even columns snapping one at a time, or,
/// with a top-to-bottom fold across the Board, fold pages snapping a page
/// at a time.
private struct BoardPlan {
    static let gap = 12.0
    /// The narrowest a stage may be on a fold page (the web's 220, less a
    /// little so two fit before the Duo's fold).
    static let foldMinWidth = 200.0

    var tracks: [FoldColumns.Track]
    var width: CGFloat
    var stride: CGFloat
    var maxOffset: CGFloat?

    init(_ proxy: GeometryProxy, count: Int) {
        let size = proxy.size
        if let x = FoldInfo.verticalFold(proxy),
           let pages = FoldColumns.pages(count: count,
                                         gap: FoldColumns.gap(around: Double(x.lowerBound)...Double(x.upperBound)),
                                         minimum: Self.foldMinWidth,
                                         spacing: Self.gap) {
            tracks = pages.tracks
            width = CGFloat(pages.contentWidth(viewport: Double(size.width)))
            stride = CGFloat(pages.stride)
            maxOffset = CGFloat(pages.lastOffset)
        } else {
            tracks = FoldColumns.even(count: count, width: Double(size.width),
                                      spacing: Self.gap, minimum: 220)
            width = CGFloat(tracks.last?.maxX ?? Double(size.width))
            stride = CGFloat((tracks.first?.width ?? 0) + Self.gap)
            maxOffset = nil
        }
    }
}

/// One column (web `BoardColumn`, Final mock `.fin-bcol`): a panel with a
/// pinned head (stage dot, name, "N waiting", count), four rows (Pending) or
/// three, "Show all N", then "Load more" and, on the windowed stages, "View
/// all in History".
struct BoardColumnView<Row: View>: View {
    let column: RequestBoard.Column
    let items: [MediaRequest]
    let board: BoardModel
    let onRetry: () -> Void
    let onLoadMore: () -> Void
    let onOpenHistory: (HistoryFilter) -> Void
    @ViewBuilder let row: (MediaRequest) -> Row
    @State private var expanded = false

    private var cap: Int { column == .pending ? 4 : 3 }
    private var label: String { column == .pending ? String(items.count) : board.countLabel(column) }
    private var collapsible: Bool { items.count > cap || board.count(column) > cap }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(expanded ? items : Array(items.prefix(cap))) { r in row(r) }
                    footer
                } header: {
                    head
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
    }

    private var head: some View {
        HStack(spacing: 8) {
            Circle().fill(column.tone.color).frame(width: 8, height: 8)
            Text(column.label).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
            if column == .pending, board.waiting > 0 {
                Text("\(board.waiting) waiting")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.miss)
                    .padding(.horizontal, 7).padding(.vertical, 1)
                    .background(Theme.miss.opacity(0.16), in: Capsule())
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(verbatim: label).font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.dim)
        }
        .padding(.top, 10).padding(.bottom, 8)
        .background(Theme.panel)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var footer: some View {
        if board.failed(column) {
            Button("Couldn’t load this column. Retry", action: onRetry).font(.system(size: 12.5))
        } else if items.isEmpty && !board.hasMore(column) {
            Text("Nothing here").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
        }
        if !expanded && collapsible {
            Button("Show all \(label)") { expanded = true }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        if expanded || !collapsible {
            if board.hasMore(column) {
                Button("Load more", action: onLoadMore).buttonStyle(.discover(.subtle)).frame(maxWidth: .infinity)
            }
            if board.capped(column) {
                Text("Showing the first \(RequestBoard.maxPages * RequestBoard.page)")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            if let history = column.history {
                Button { onOpenHistory(history) } label: { Label("View all in History", systemImage: "arrow.right") }
                    .font(.system(size: 13, weight: .semibold))
                    .labelStyle(TrailingIconLabel())
            }
        }
    }
}

/// "View all in History →": the arrow after the words, like the web.
private struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon }
    }
}
