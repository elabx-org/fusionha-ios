import SwiftUI

// The Automatic requests cards' marks, ported from the web's
// `account/watchlist/icons.tsx` (`ListMarkIcon`) and
// `account/letterboxd/icons.tsx` (`LbIcon`) as template shapes on the same
// 24×24 grid: they draw in the current foreground style, like `currentColor`.

/// `LbIcon`: three outlined dots.
struct LbMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        for x in [6.5, 12, 17.5] as [CGFloat] {
            path.addEllipse(in: CGRect(x: (x - 3.6) * scale, y: (12 - 3.6) * scale,
                                       width: 7.2 * scale, height: 7.2 * scale))
        }
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// `ListMarkIcon`: three list lines and a plus.
struct ListMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            path.move(to: CGPoint(x: x1 * s, y: y1 * s))
            path.addLine(to: CGPoint(x: x2 * s, y: y2 * s))
        }
        line(4, 6, 15, 6)
        line(4, 12, 12, 12)
        line(4, 18, 12, 18)
        line(18, 13, 18, 20)
        line(14.5, 16.5, 21.5, 16.5)
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// Which mark a watchlist card head shows.
enum WatchlistMark {
    case list, letterboxd

    /// The glyph's ink: the web's `.ico` (`--mut`) and `.icoLb` (`--i2`).
    /// Grey under Monochrome (ruling G4).
    var ink: Color {
        switch self {
        case .list: return Theme.mut
        case .letterboxd: return Theme.isMono ? Theme.mut : Theme.i2
        }
    }
}

/// A mark stroked 1.8 on its 24 grid (round caps and joins), in `size` points.
struct WatchlistMarkGlyph: View {
    let mark: WatchlistMark
    var size: CGFloat = 18

    var body: some View {
        let style = StrokeStyle(lineWidth: 1.8 * size / 24, lineCap: .round, lineJoin: .round)
        Group {
            switch mark {
            case .list: ListMarkShape().stroke(style: style)
            case .letterboxd: LbMarkShape().stroke(style: style)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
