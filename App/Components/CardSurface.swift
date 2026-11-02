import SwiftUI

/// How a card looks where the palette doesn't lift cards (Daylight, Noir).
enum FlatCardEdge {
    /// The web `panel` hairline: `Theme.line`, 1pt.
    case line
    /// The shelf object's faint edge: `txt` at 6%, 0.5pt.
    case faint
}

/// One card surface for the whole app. In a dark palette with a raised
/// `card` tone (`Theme.liftsCards`) the card is lifted: the lighter fill, a
/// top-lit hairline (the palette's line colour, 20% at the top to 5% at the
/// bottom) and one soft shadow under the shape. Elsewhere it keeps the flat
/// look it had: `Theme.card` (or `flatFill`), its hairline and, for shelf
/// objects, the old falloff shadow.
///
/// The shadow is drawn by the background shape only, never the content, so
/// it is one cheap blur per card. Leave `lift` off for rows stacked in a long
/// lazy list (release results), and never use this for rows, chips or pills
/// inside a card, or for glass controls.
struct CardSurface: ViewModifier {
    let radius: CGFloat
    /// Lifted palettes: draw the soft shadow.
    var lift = true
    /// Flat palettes: the shelf object's falloff shadow.
    var flatShadow = false
    var flatEdge: FlatCardEdge = .line
    /// Flat palettes: the fill (nil = `Theme.card`). Lifted cards always use `Theme.card`.
    var flatFill: Color? = nil

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let lifted = Theme.liftsCards
        let fill = lifted ? Theme.card : (flatFill ?? Theme.card)
        let shadowOn = lifted ? lift : flatShadow
        return content
            .background {
                shape
                    .fill(fill)
                    .shadow(color: .black.opacity(shadowOn ? (lifted ? 0.5 : 0.55) : 0),
                            radius: shadowOn ? (lifted ? 13 : 14) : 0,
                            y: shadowOn ? (lifted ? 7 : 10) : 0)
            }
            .overlay {
                if lifted {
                    shape.strokeBorder(Self.litEdge, lineWidth: 1)
                } else if flatEdge == .faint {
                    shape.strokeBorder(Theme.txt.opacity(0.06), lineWidth: 0.5)
                } else {
                    shape.strokeBorder(Theme.line, lineWidth: 1)
                }
            }
    }

    /// The top-lit hairline: the palette's line colour, bright at the top.
    static var litEdge: LinearGradient {
        let line = Color(hex: Theme.palette.line)
        return LinearGradient(colors: [line.opacity(0.20), line.opacity(0.05)], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    /// A card (`cardSurface`): lifted in dark palettes, flat in Daylight and
    /// Noir. See `CardSurface`.
    func cardSurface(radius: CGFloat = Theme.radiusLg, lift: Bool = true, flatShadow: Bool = false,
                     flatEdge: FlatCardEdge = .line, flatFill: Color? = nil) -> some View {
        modifier(CardSurface(radius: radius, lift: lift, flatShadow: flatShadow, flatEdge: flatEdge, flatFill: flatFill))
    }
}
