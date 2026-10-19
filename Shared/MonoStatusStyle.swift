import SwiftUI
import FusionhaKit

// Monochrome's status language on screen (fusionha 0.4.221 `statusFill` /
// `StatusGlyph`): a status paints its shade with its pattern over it, and a
// legend or label adds its glyph. Off Monochrome every piece here is a no-op,
// so the other palettes render exactly as before.

extension Theme {
    /// A status token's colour in the active palette (`var(--token)`).
    static func color(_ token: MonoToken) -> Color {
        switch token {
        case .done: return done
        case .grab: return grab
        case .miss: return miss
        case .unaired: return unaired
        case .unmonitored: return unmonitored
        case .onair: return onair
        case .premiere: return premiere
        case .stuck: return stuck
        case .edition: return edition
        case .anime: return anime
        case .danger: return danger
        }
    }

    /// A tier's fill: its chip grey under Monochrome (`--tier-chip-*`, HD light,
    /// 4K mid), its hue (HD purple, 4K cyan) everywhere else.
    static func tierFill(_ tier: QualityTier) -> Color {
        if isMono, let hex = tier == .hd ? palette.tierChipHd : palette.tierChipUhd { return Color(hex: hex) }
        return tier.color
    }

    /// The ink a pattern is drawn in over a status fill (the web's `rgba(0,0,0,.6)`).
    static var patternInk: Color { bg.opacity(0.6) }
}

extension MonoToken {
    var color: Color { Theme.color(self) }

    /// The token behind a bare status colour, for surfaces that only pass a
    /// colour. Equal greys resolve to the first match (Monochrome's bright
    /// done / grab / edition / danger all read as done), so status surfaces
    /// pass their token explicitly.
    static func matching(_ color: Color) -> MonoToken? {
        let order: [MonoToken] = [.miss, .unaired, .unmonitored, .onair, .stuck, .premiere, .done]
        return order.first { Theme.color($0) == color }
    }
}

/// A status colour with the token Monochrome draws it as.
struct StatusTone: Equatable {
    let color: Color
    let mono: MonoToken?

    init(_ token: MonoToken) {
        color = token.color
        mono = token
    }

    /// A tone that is not a status (a neutral `dim` wash): no pattern.
    init(color: Color, mono: MonoToken? = nil) {
        self.color = color
        self.mono = mono
    }
}

// MARK: Pattern

extension MonoPattern {
    /// The tiled marks for `size`: lines to stroke and shapes to fill.
    func marks(in size: CGSize, cell: CGFloat) -> (stroke: Path, fill: Path) {
        var stroke = Path()
        var fill = Path()
        guard self != .none, cell > 0 else { return (stroke, fill) }
        let half = cell / 2
        for y in stride(from: 0, to: size.height, by: cell) {
            for x in stride(from: 0, to: size.width, by: cell) {
                switch self {
                case .none: break
                case .diag: stroke.move(to: .init(x: x, y: y + cell)); stroke.addLine(to: .init(x: x + cell, y: y))
                case .anti: stroke.move(to: .init(x: x, y: y)); stroke.addLine(to: .init(x: x + cell, y: y + cell))
                case .horiz: stroke.move(to: .init(x: x, y: y + half)); stroke.addLine(to: .init(x: x + cell, y: y + half))
                case .vert: stroke.move(to: .init(x: x + half, y: y)); stroke.addLine(to: .init(x: x + half, y: y + cell))
                case .cross:
                    stroke.move(to: .init(x: x, y: y + half)); stroke.addLine(to: .init(x: x + cell, y: y + half))
                    stroke.move(to: .init(x: x + half, y: y)); stroke.addLine(to: .init(x: x + half, y: y + cell))
                case .dots, .dense:
                    let r = cell * (self == .dense ? 0.27 : 0.225)
                    fill.addEllipse(in: CGRect(x: x + half - r, y: y + half - r, width: r * 2, height: r * 2))
                case .check:
                    fill.addRect(CGRect(x: x, y: y, width: half, height: half))
                    fill.addRect(CGRect(x: x + half, y: y + half, width: half, height: half))
                case .wave:
                    stroke.move(to: .init(x: x, y: y + cell * 0.75))
                    stroke.addQuadCurve(to: .init(x: x + half, y: y + cell * 0.75), control: .init(x: x + cell / 4, y: y + cell * 0.25))
                    stroke.addQuadCurve(to: .init(x: x + cell, y: y + cell * 0.75), control: .init(x: x + cell * 0.75, y: y + cell * 1.25))
                }
            }
        }
        return (stroke, fill)
    }
}

/// A Monochrome pattern drawn crisp in a Canvas (the web's `--p-*` tiles).
struct MonoPatternFill: View {
    let pattern: MonoPattern
    var ink: Color = Theme.patternInk
    /// Tile edge; defaults to the web's 4pt (3pt dense).
    var cell: CGFloat? = nil
    var lineWidth: CGFloat? = nil

    var body: some View {
        if pattern != .none {
            Canvas { context, size in
                let edge = cell ?? CGFloat(pattern.cell)
                let marks = pattern.marks(in: size, cell: edge)
                context.stroke(marks.stroke, with: .color(ink), lineWidth: lineWidth ?? edge * 0.3)
                context.fill(marks.fill, with: .color(ink))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: Fill, glyph

/// `statusFill`: a status swatch (dot, bar, segment) in its colour, with its
/// pattern over it under Monochrome.
struct StatusSwatch<S: Shape>: View {
    let token: MonoToken
    let shape: S
    /// A colour other than the token's own (a dimmed or mixed fill).
    var color: Color? = nil

    var body: some View {
        shape.fill(color ?? token.color)
            .overlay {
                if Theme.isMono { MonoPatternFill(pattern: token.pattern).clipShape(shape) }
            }
    }
}

extension StatusSwatch where S == Circle {
    /// A status dot.
    init(_ token: MonoToken, color: Color? = nil) {
        self.init(token: token, shape: Circle(), color: color)
    }
}

/// `StatusGlyph`: the status' Monochrome glyph (✓ ↓ ○ …), shown only under
/// Monochrome so the other palettes keep their layout.
struct StatusGlyph: View {
    let token: MonoToken
    var size: CGFloat = 9
    var color: Color? = nil

    var body: some View {
        if Theme.isMono {
            Image(systemName: token.symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(color ?? token.color)
                .accessibilityHidden(true)
        }
    }
}

/// A status dot that, under Monochrome, is the status' glyph instead: at 6–8pt
/// a pattern is barely legible, a glyph always is.
struct StatusDot: View {
    let token: MonoToken
    var size: CGFloat = 6
    var color: Color? = nil

    var body: some View {
        if Theme.isMono {
            StatusGlyph(token: token, size: max(size + 2, 8), color: color)
                .frame(minWidth: size, minHeight: size)
        } else {
            Circle().fill(color ?? token.color).frame(width: size, height: size)
        }
    }
}

/// The wash a status card wears under Monochrome: a solid low shade with the
/// status' pattern at low contrast (no gradient), so every washed surface
/// keeps its meaning without hue.
struct MonoWash: View {
    let token: MonoToken?
    let color: Color
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(color.opacity(0.07))
            .overlay {
                if let token {
                    MonoPatternFill(pattern: token.pattern, ink: color.opacity(0.10), cell: 6, lineWidth: 1).clipShape(shape)
                }
            }
    }
}
