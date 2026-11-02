import SwiftUI

/// The split title's backdrop (`DetailHeroBackdrop` in its band style): the
/// art behind the band across both pages and on down both, under the ground
/// wash their text needs. The left page's art fades out at the top of its
/// Versions and follows it as the page scrolls (never above the strip); the
/// right page's fades at the same level, held where it was laid out. Beside
/// an episode both use that level. The title's dark shade covers the left
/// page and however far a long title runs past it.
struct SpreadHeroBackdrop: View {
    let url: URL?
    /// The band's frame (global): its height is the art's edge.
    let band: CGRect
    let metrics: HeroHeaderMetrics
    let tracker: HeroScrollTracker
    /// The left page's width.
    let column: CGFloat
    /// How far the band's text runs from its leading edge.
    let textWidth: CGFloat
    /// An episode is the right page: no facts on the left.
    let beside: Bool

    var body: some View {
        let edge = band.height
        let handover = HeroBackdropLayout.handover(edge: edge, stripEnd: metrics.stripEnd)
        // Where Versions sit when the page is at rest, at least a hero's run.
        let rest = edge + max(metrics.versionsTop, 320)
        let live = tracker.versionsOnScreen.map { $0 - band.minY } ?? rest
        let foot = beside ? rest : min(max(live, handover + 48), rest)
        DetailHeroBackdrop(
            url: url,
            layout: HeroBackdropLayout(style: .band, edge: edge, handover: handover, foot: foot,
                                       farFoot: rest, column: column,
                                       shadeColumn: max(column, textWidth + 48), originY: band.minY),
            underBar: true)
    }
}
