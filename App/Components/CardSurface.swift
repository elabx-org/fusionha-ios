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
    /// The title page's colour bleed (`cardBleed`, set over the art ground).
    @Environment(\.cardBleed) private var bleedHere

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let lifted = Theme.liftsCards
        let bleed = lifted && bleedHere
        let fill = bleed ? Self.bleedFill : (lifted ? Theme.card : (flatFill ?? Theme.card))
        let shadowOn = lifted ? lift : flatShadow
        return content
            .background {
                if bleed {
                    BleedCardGround(shape: shape, fill: fill, shadow: shadowOn)
                } else {
                    shape
                        .fill(fill)
                        .shadow(color: .black.opacity(shadowOn ? (lifted ? 0.5 : 0.55) : 0),
                                radius: shadowOn ? (lifted ? 13 : 14) : 0,
                                y: shadowOn ? (lifted ? 7 : 10) : 0)
                }
            }
            .overlay {
                if bleed {
                    shape.strokeBorder(Self.bleedEdge, lineWidth: 1)
                } else if lifted {
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

    /// Colour bleed: the palette's panel at 52%, so the art ground shows
    /// through while text keeps its contrast. A see-through fill, not glass.
    static var bleedFill: Color { Theme.panel.opacity(0.52) }

    /// Colour bleed: the lit hairline a little brighter, to hold the edge.
    static var bleedEdge: LinearGradient {
        let line = Color(hex: Theme.palette.line)
        return LinearGradient(colors: [line.opacity(0.24), line.opacity(0.05)], startPoint: .top, endPoint: .bottom)
    }
}

/// A see-through card's ground: the translucent fill, and the soft shadow
/// drawn outside the shape only (masked out of the inside), so it never
/// darkens the art showing through the card.
private struct BleedCardGround: View {
    let shape: RoundedRectangle
    let fill: Color
    let shadow: Bool

    var body: some View {
        ZStack {
            if shadow {
                shape
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.5), radius: 13, y: 7)
                    .mask {
                        Rectangle().inset(by: -48).subtracting(shape)
                    }
            }
            shape.fill(fill)
        }
    }
}

extension EnvironmentValues {
    /// True where cards sit over the title page's art ground: lifted cards
    /// turn see-through there (`CardSurface`). Off everywhere else.
    @Entry var cardBleed = false
}

extension View {
    /// A card (`cardSurface`): lifted in dark palettes, flat in Daylight and
    /// Noir. See `CardSurface`.
    func cardSurface(radius: CGFloat = Theme.radiusLg, lift: Bool = true, flatShadow: Bool = false,
                     flatEdge: FlatCardEdge = .line, flatFill: Color? = nil) -> some View {
        modifier(CardSurface(radius: radius, lift: lift, flatShadow: flatShadow, flatEdge: flatEdge, flatFill: flatFill))
    }
}
