import SwiftUI
import FusionhaKit

/// Recently added on a wide page (Home mock, open): the zipper. A spine runs
/// down the page's centre; tiles alternate left and right of it, staggered,
/// each tied to it by a dot and a short connector, and slide out from it as
/// they come into view (none with Reduce Motion). Flat, the spine is only a
/// design element: the tiles sit the ordinary 20pt from it and nothing is
/// kept for the hinge. In book pose the spine sits on the fold.
struct V2RecentZipper: View {
    let items: [MediaItem]
    @Environment(\.pagePalette) private var page
    @State private var panes: FoldColumns.Panes?
    @State private var width: CGFloat = 0

    private static let side: CGFloat = 20

    private var lead: CGFloat { panes.map { CGFloat($0.lead) } ?? max(0, width / 2 - Self.side) }
    private var gap: CGFloat { panes.map { CGFloat($0.gap) } ?? 2 * Self.side }
    private var spine: CGFloat { lead + gap / 2 }
    private var tile: CGFloat { max(160, min(300, lead)) }
    /// The tile's height: day label, 16:9 art, caption.
    private var tileHeight: CGFloat { 23 + (tile * 9 / 16).rounded() + 52 }
    private var step: CGFloat { (tileHeight * 0.6).rounded() }
    private var dotY: CGFloat { 23 + (tile * 9 / 32).rounded() }

    var body: some View {
        let ink = page?.ink ?? Theme.txt
        let total = items.isEmpty ? 0 : CGFloat(items.count - 1) * step + tileHeight
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [ink.opacity(0.28), ink.opacity(0.06)], startPoint: .top, endPoint: .bottom)
                .frame(width: 2, height: max(0, total - 40))
                .offset(x: spine - 1)
            ForEach(Array(items.enumerated()), id: \.element.id) { k, item in
                let left = k.isMultiple(of: 2)
                let y = CGFloat(k) * step
                Rectangle()
                    .fill(ink.opacity(0.25))
                    .frame(width: max(0, gap / 2 - 5), height: 2)
                    .offset(x: left ? lead : spine + 5, y: y + dotY + 4)
                Circle()
                    .fill(ink)
                    .frame(width: 10, height: 10)
                    .background(Circle().fill(ink.opacity(0.12)).padding(-4))
                    .offset(x: spine - 5, y: y + dotY)
                V2RecentTile(item: item, width: tile, leading: left)
                    .offset(x: left ? lead - tile : lead + gap, y: y)
            }
        }
        .frame(maxWidth: .infinity, minHeight: total, maxHeight: total, alignment: .topLeading)
        .onGeometryChange(for: FoldColumns.Panes?.self) { V2HomePairFold.panes($0) } action: { panes = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

/// One zipper tile: the day, the 16:9 art, the title and note with the
/// tickets at the far end. Slides out from the spine when it comes into view.
struct V2RecentTile: View {
    let item: MediaItem
    let width: CGFloat
    /// Left of the spine (its day label aligns to the spine side).
    let leading: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    var body: some View {
        Button { model.open(item.id) } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(V2RecentWords.day(V2RecentWords.added(item)).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .frame(maxWidth: .infinity, alignment: leading ? .trailing : .leading)
                    .frame(height: 17)
                    .padding(.bottom, 6)
                V2BackdropThumb(item: item, width: width)
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(page?.ink ?? Theme.txt)
                        Text(V2RecentWords.note(item))
                            .font(.system(size: 13))
                            .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                    V2ItemTickets(item: item).padding(.top, 2)
                }
                .padding(.top, 10)
                .padding(.horizontal, 2)
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: motion && !shown ? (leading ? 30 : -30) : 0)
        .onScrollVisibilityChange(threshold: 0.25) { visible in
            guard visible, !shown else { return }
            withAnimation(motion ? .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.6) : nil) { shown = true }
        }
        .accessibilityElement(children: .combine)
    }
}
