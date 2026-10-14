import SwiftUI
import FusionhaKit

// MARK: Glyphs (the web's 24-unit stroke icons)

/// The web's line icons, drawn in a 24×24 box and stroked at 1.9.
struct LineGlyph: View {
    enum Kind {
        case movie, series, anime, feed
    }

    let kind: Kind
    var size: CGFloat = 13
    var lineWidth: CGFloat = 1.9

    var body: some View {
        GlyphShape(kind: kind)
            .stroke(style: StrokeStyle(lineWidth: lineWidth * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }

    static func kind(for entry: CalendarEntry) -> Kind {
        entry.isAnime ? .anime : (entry.isMovie ? .movie : .series)
    }
}

private struct GlyphShape: Shape {
    let kind: LineGlyph.Kind

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            path.move(to: p(a.0, a.1))
            path.addLine(to: p(b.0, b.1))
        }
        func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
            path.addRoundedRect(in: CGRect(x: rect.minX + x * s, y: rect.minY + y * s, width: w * s, height: h * s),
                                cornerSize: CGSize(width: r * s, height: r * s))
        }
        switch kind {
        case .movie:
            rrect(3, 4, 18, 16, 2)
            line((7.5, 4), (7.5, 20)); line((16.5, 4), (16.5, 20))
            line((3, 9.3), (7.5, 9.3)); line((3, 14.7), (7.5, 14.7))
            line((16.5, 9.3), (21, 9.3)); line((16.5, 14.7), (21, 14.7))
        case .series:
            rrect(3, 7, 18, 13, 2)
            path.move(to: p(8.5, 2.5)); path.addLine(to: p(12, 6)); path.addLine(to: p(15.5, 2.5))
        case .anime:
            path.move(to: p(3, 6))
            path.addCurve(to: p(21, 6), control1: p(5.8, 4.6), control2: p(18.2, 4.6))
            line((6.2, 5.1), (5.4, 20)); line((17.8, 5.1), (18.6, 20))
            line((4.5, 10.5), (19.5, 10.5)); line((12, 5.4), (12, 10.5))
        case .feed:
            rrect(3, 5, 18, 16, 2)
            line((8, 3), (8, 7)); line((16, 3), (16, 7))
            line((3, 11), (21, 11)); line((10.5, 16.5), (13.5, 16.5))
        }
        return path
    }
}
