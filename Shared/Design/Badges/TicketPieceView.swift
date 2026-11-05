import SwiftUI
import FusionhaKit

/// One badge piece drawn in its state: filled with the letters knocked out
/// (on disk, partly), a secondary outline (missing, downloading) or an
/// orange outline with "!" (held). `side` nil is a lone badge (a rounded
/// rectangle); `.left` / `.right` are the halves of the HD/4K ticket.
struct TicketPieceView: View {
    var side: TicketPiece.Side?
    var letters: String
    var state: EditionBadgeState
    /// The body width at the default size (`TicketMetrics`).
    var width: CGFloat
    var scale: CGFloat
    var ink: BadgeInk
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let h = TicketMetrics.height * scale
        let w = TicketMetrics.snap(width * scale, displayScale)
        let line = max(TicketMetrics.snap(TicketMetrics.stroke * scale, displayScale), 1 / max(displayScale, 1))
        shape(line: line)
            .frame(width: w, height: h)
            .overlay(alignment: .leading) { label(w: w) }
    }

    @ViewBuilder
    private func shape(line: CGFloat) -> some View {
        let tone = state.isHeld ? ink.held : ink.secondary
        // Outlines are stroked on the path like the mock's SVG (half the
        // line falls outside), so a joined pair's seams keep the same gap.
        switch side {
        case .none:
            let r = TicketMetrics.radius * scale
            if state.isFilled {
                RoundedRectangle(cornerRadius: r, style: .circular).fill(ink.fill)
            } else {
                RoundedRectangle(cornerRadius: r, style: .circular).stroke(tone, lineWidth: line)
            }
        case .some(let side):
            if state.isFilled {
                TicketPiece(side: side).fill(ink.fill)
            } else {
                TicketPiece(side: side).stroke(tone, lineWidth: line)
            }
        }
    }

    /// The letters, centred clear of the seam: the left half centres them on
    /// its body less the joined gap, the right half shifts them past it.
    private func label(w: CGFloat) -> some View {
        let gap = side == nil ? 0 : TicketMetrics.joinedGap * scale
        let lead: CGFloat = side == .right ? gap : 0
        let colour = state.isFilled ? ink.knockout : state.isHeld ? ink.held : ink.secondary
        // Held reads "HD!" in one run, as the mock's ticket draws it.
        return Text(verbatim: state.isHeld ? letters + "!" : letters)
            .font(.system(size: TicketMetrics.letterSize * scale, weight: .semibold))
            .tracking(TicketMetrics.letterTracking * scale)
            .foregroundStyle(colour)
            .lineLimit(1)
            .fixedSize()
            .frame(width: max(0, w - gap), alignment: .center)
            .padding(.leading, lead)
    }
}
