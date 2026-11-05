import SwiftUI
import FusionhaKit

/// v2's one-ink rail (mock rails.js, owner 2026-11-04): a 4pt capsule that
/// shows an amount. On disk is the label ink, missing is the empty track,
/// downloading the accent, held orange, and episodes not out yet a hollow
/// outline. Which version it is, is said by the badge beside it.
struct RailBarV2: View {
    var spans: [OneInkRail.Span]
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 4
    @Environment(\.badgeInk) private var inkOverride
    @Environment(\.displayScale) private var displayScale

    /// A season: `have` on disk of `aired`, of `total` episodes.
    init(have: Int, aired: Int, total: Int, rest: OneInkRail.Piece = .missing) {
        spans = OneInkRail.spans(have: have, aired: aired, total: total, rest: rest)
    }

    /// A download: the accent up to `progress` (0...1), the rest track.
    init(progress: Double) {
        let p = min(1, max(0, progress))
        spans = p > 0 ? [OneInkRail.Span(piece: .downloading, fraction: p)] : []
    }

    init(spans: [OneInkRail.Span]) {
        self.spans = spans
    }

    var body: some View {
        let ink = inkOverride ?? .page
        let hairline = 1 / max(displayScale, 1)
        Canvas { ctx, size in
            let bar = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2)
            ctx.fill(bar, with: .color(ink.track))
            ctx.clip(to: bar)
            var x: CGFloat = 0
            for span in spans {
                let w = size.width * span.fraction
                let rect = CGRect(x: x, y: 0, width: w, height: size.height)
                x += w
                draw(span.piece, in: rect, bar: size, ctx: &ctx, ink: ink, line: max(hairline, 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func draw(_ piece: OneInkRail.Piece, in rect: CGRect, bar size: CGSize,
                      ctx: inout GraphicsContext, ink: BadgeInk, line: CGFloat) {
        let inset = rect.insetBy(dx: line / 2, dy: line / 2)
        switch piece {
        case .onDisk: ctx.fill(Path(rect), with: .color(ink.fill))
        case .downloading where ink.patterned:
            var layer = ctx
            layer.clip(to: Path(rect))
            layer.stroke(RailPattern.hatch(in: rect), with: .color(ink.accent), lineWidth: 1)
        case .downloading: ctx.fill(Path(rect), with: .color(ink.accent))
        case .held where ink.patterned:
            ctx.stroke(Path(roundedRect: inset, cornerRadius: max(0, size.height / 2 - line / 2)),
                       with: .color(ink.held), lineWidth: line)
        case .held: ctx.fill(Path(rect), with: .color(ink.held))
        case .missing: break
        case .unaired:
            // Hollow: the mock's 1px inset outline, square where it meets the
            // stretch before it and rounded at the end (the bar's clip rounds
            // the start when it is the whole bar).
            let r = max(0, size.height / 2 - line / 2)
            let outline = UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                                 bottomTrailingRadius: r, topTrailingRadius: r,
                                                 style: .circular).path(in: inset)
            ctx.stroke(outline, with: .color(ink.secondary), lineWidth: line)
        }
    }
}
