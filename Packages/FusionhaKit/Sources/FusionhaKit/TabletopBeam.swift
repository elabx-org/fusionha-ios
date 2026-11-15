import Foundation

/// The hologram's projection light (owner, 2026-11-15: "there's no
/// projection light coming from the disc"): the emitter glows, a cone of
/// light rises from it to the card's foot, and the light is brightest in a
/// band across the fold, over the card's foot on both halves, so the card's
/// lower edge and the join dissolve into glare. Up the card it thins out
/// and is gone by `columnReach` of the card's height. Pure numbers; the app
/// draws them as soft gradients only (`V2HologramLight`).
///
/// Distances here are design points on the display (669 wide) measured
/// from the fold line: `rise` positive up the upright half, negative out
/// over the table half. The band is a function of the distance alone, so
/// the light has the same strength and the same width on both sides of the
/// fold line.
public enum TabletopBeam {
    /// The band across the fold: whole to `bandCore` either side of the
    /// fold line, eased out to nothing by `bandReach`.
    public static let bandCore = 24.0
    public static let bandReach = 80.0
    /// The band's strength at the fold line.
    public static let bandPeak = 0.6
    /// The light rising up the card, at the fold line; it is gone by
    /// `columnReach` of the card's height on the upright half, and on the
    /// table half it eases out over `bandReach` like the band.
    public static let columnPeak = 0.3
    public static let columnReach = 0.45
    /// The band's and the column's width against the card's (feathered sides).
    public static let widthRatio = 1.3
    /// The cone on the table: half as wide as the emitter's dashed inner
    /// ring at the disc, `coneFootRatio` of the card's width at its foot.
    public static let coneDiscHalfWidth = TabletopScene.emitterRadius - 24
    public static let coneFootRatio = 1.1
    /// The light breathes: ±`breathReach` over `breathPeriod` seconds.
    public static let breathReach = 0.08
    public static let breathPeriod = 3.0
    /// Thin scan lines travel up through the light: one every
    /// `scanSpacing`, at `scanSpeed` points a second.
    public static let scanSpacing = 34.0
    public static let scanSpeed = 12.0

    /// The band at `rise` from the fold line (either sign).
    public static func band(_ rise: Double) -> Double {
        bandPeak * (1 - TabletopScene.smoothstep((abs(rise) - bandCore) / (bandReach - bandCore)))
    }

    /// The light at `rise` from the fold line, for a card drawn `cardHeight`
    /// up the upright half: the band plus the column. Brightest at the fold
    /// line (`peak`), the same either side of it, nothing past `reach` up
    /// the upright half or `bandReach` out over the table.
    public static func strength(rise: Double, cardHeight: Double) -> Double {
        let column: Double
        if rise >= 0 {
            column = 1 - TabletopScene.smoothstep(rise / max(columnReach * cardHeight, 1))
        } else {
            column = 1 - TabletopScene.smoothstep(-rise / bandReach)
        }
        return band(rise) + columnPeak * column
    }

    /// The light at the fold line.
    public static var peak: Double { bandPeak + columnPeak }

    /// How far up the upright half the light reaches for a card drawn
    /// `cardHeight` up it.
    public static func reach(cardHeight: Double) -> Double {
        max(columnReach * cardHeight, bandReach)
    }

    /// The band's width (the same on both halves) for a card `cardWidth` wide.
    public static func width(cardWidth: Double) -> Double { widthRatio * cardWidth }

    /// The breath at `seconds` (1 standing still).
    public static func breath(at seconds: Double?) -> Double {
        guard let seconds else { return 1 }
        return 1 + breathReach * sin(seconds * 2 * Double.pi / breathPeriod)
    }

    /// The light through the lift (0 flat … 1 hologram): it comes on over
    /// the last third.
    public static func lift(_ progress: Double) -> Double {
        TabletopScene.smoothstep((progress - 2.0 / 3.0) * 3)
    }

    /// The light for a lead title `focus` focused: it dips while the ring
    /// turns between two titles (a quarter half way) and returns.
    public static func focus(_ focus: Double) -> Double { focus * focus }

    /// The scan lines' rises `seconds` into the idle loop (nil: still, at
    /// their resting places), from `bandReach` out on the table up to
    /// `reach(cardHeight:)`, travelling up.
    public static func scanLines(at seconds: Double?, cardHeight: Double) -> [Double] {
        let low = -bandReach, high = reach(cardHeight: cardHeight)
        let travelled = ((seconds ?? 0) * scanSpeed).truncatingRemainder(dividingBy: scanSpacing)
        let shift = travelled < 0 ? travelled + scanSpacing : travelled
        var lines: [Double] = []
        var rise = low + shift
        while rise <= high {
            lines.append(rise)
            rise += scanSpacing
        }
        return lines
    }

    /// The cone from the disc to the card's foot: [foot left, foot right,
    /// disc right, disc left], lying from the floor up to the foot.
    public static func cone(_ card: TabletopScene.Card) -> [TabletopVec] {
        let foot = card.width * coneFootRatio / 2, disc = coneDiscHalfWidth
        return [TabletopVec(card.centerX - foot, -card.lift, card.centerZ),
                TabletopVec(card.centerX + foot, -card.lift, card.centerZ),
                TabletopVec(disc, 0, TabletopScene.ringZ), TabletopVec(-disc, 0, TabletopScene.ringZ)]
    }

    /// The card's contact shadow on the table: its turned foot's footprint
    /// (the poster and its slices) on the floor, `margin` wider all round,
    /// [far left, far right, near right, near left] in the card's own turn.
    public static func contact(_ card: TabletopScene.Card, margin: Double = 16) -> [TabletopVec] {
        let sn = sin(card.yaw), cs = cos(card.yaw)
        let depth = Double(TabletopScene.sliceCount) * TabletopScene.sliceGap * card.focus
        // Along the foot, and along the card's facing (its slices behind it).
        let a = card.width / 2 + margin, b = depth / 2 + margin
        let cx = card.centerX - sn * depth / 2, cz = card.centerZ - cs * depth / 2
        func at(_ u: Double, _ v: Double) -> TabletopVec {
            TabletopVec(cx + u * cs + v * sn, 0, cz - u * sn + v * cs)
        }
        return [at(-a, -b), at(a, -b), at(a, b), at(-a, b)]
    }
}
