import SwiftUI
import UIKit
import FusionhaKit

/// The book's gutter over the grounds and the pages' edges: a soft shadow
/// deepening toward the crease (the right page a touch darker, light from
/// the upper left), the crease's dark line with a thin highlight where each
/// page turns, and pale binding thread along it (`BookGutter` has the numbers).
struct V2GutterShade: View {
    let width: CGFloat
    /// The crease's x in this view.
    let crease: CGFloat
    let depth: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(stops: shadowStops, startPoint: .leading, endPoint: .trailing)
            LinearGradient(stops: creaseStops, startPoint: .leading, endPoint: .trailing)
                .frame(width: 40)
                .offset(x: crease - 20)
            V2GutterThread(depth: depth)
                .frame(width: 8)
                .offset(x: crease - 4)
        }
        .frame(width: width)
    }

    /// The broad shadow, sampled across the strip.
    private var shadowStops: [Gradient.Stop] {
        guard width > 0 else { return [] }
        return (0...32).map { i in
            let x = width * CGFloat(i) / 32
            let d = Double(x - crease)
            let a = BookGutter.shadow(at: d, rightPage: d > 0, depth: depth)
            return .init(color: .black.opacity(a), location: CGFloat(i) / 32)
        }
    }

    /// The crease: dark down the middle, a faint light 5pt either side.
    private var creaseStops: [Gradient.Stop] {
        let line = BookGutter.crease(depth)
        let width = 4 + 2 * depth
        let shine = 0.05 + 0.08 * depth
        return (0...20).map { i in
            let d = Double(i - 10) * 2          // −20…20 pt from the crease
            let dark = line * exp(-pow(d / width, 2))
            let light = shine * exp(-pow((abs(d) - 5) / 2.5, 2))
            let color: Color = dark >= light ? .black.opacity(dark) : .white.opacity(light)
            return .init(color: color, location: CGFloat(i) / 20)
        }
    }
}

/// Short pale stitches down the crease, as in a sewn book, each with the
/// shadow of its hole below it.
struct V2GutterThread: View {
    let depth: Double

    var body: some View {
        Canvas { context, size in
            let opacity = BookGutter.thread(depth)
            let pitch = BookGutter.stitchPitch
            var y = 24.0
            while y + 12 < Double(size.height) {
                let stitch = CGRect(x: size.width / 2 - 1.2, y: y, width: 2.4, height: 11)
                context.fill(Path(roundedRect: stitch, cornerRadius: 1.2),
                             with: .color(Color(red: 0.89, green: 0.86, blue: 0.80).opacity(opacity)))
                let hole = CGRect(x: size.width / 2 - 1, y: y + 11, width: 2, height: 1.4)
                context.fill(Path(hole), with: .color(.black.opacity(0.35 * depth)))
                y += pitch
            }
        }
    }
}

/// Reads the hinge in book pose and eases the gutter's depth after it
/// (`BookGutter.depth`). With Reduce Motion: three steps, a quick fade. The
/// angle is used for this drawing only, never for layout (Apple's rule for
/// hinge data); before the first reading the gutter sits midway.
struct V2HingeDepth: ViewModifier {
    @Binding var depth: Double
    @Environment(\.motionEnabled) private var motion

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, new in
                guard let degrees = new.hinge?.angle.degrees else { return }
                let next = BookGutter.depth(degrees: degrees, steps: !motion)
                guard abs(next - depth) > 0.01 else { return }
                withAnimation(motion ? .smooth(duration: 0.25) : .easeOut(duration: 0.15)) { depth = next }
            }
        } else {
            content
        }
    }
}

/// A colour's tone, for lifting a near-black ground.
enum V2GutterTone {
    static func luminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return 1 }
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }

    static func saturation(_ color: Color) -> Double {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getHue(&h, saturation: &s, brightness: &v, alpha: &a) else { return 0 }
        return Double(s)
    }
}
