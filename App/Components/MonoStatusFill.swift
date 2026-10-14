import SwiftUI
import FusionhaKit

/// Monochrome's status fills: with no hue to lean on, each state is a shade
/// and a texture (the palette mock's "status by shade and pattern").
/// Done is a lit white gradient, downloading a diagonal stripe, wanted
/// dotted, upcoming an outline, a warning (dead links, not found) a fine hatch.
enum MonoStatus {
    case done, downloading, wanted, upcoming, upgrading, warning

    init(_ state: RailState, attention: Bool) {
        if attention { self = .warning; return }
        switch state {
        case .owned: self = .done
        case .downloading: self = .downloading
        case .partial, .wanted: self = .wanted
        case .upcoming: self = .upcoming
        case .upgrading: self = .upgrading
        }
    }
}

/// A rail fill in Monochrome. Drawn in a Canvas so the pattern stays crisp at 4pt.
struct MonoRailFill: View {
    let status: MonoStatus

    var body: some View {
        switch status {
        case .done:
            Capsule().fill(LinearGradient(colors: [Theme.txt.opacity(0.55), Theme.txt], startPoint: .leading, endPoint: .trailing))
        case .upgrading:
            Capsule().fill(LinearGradient(colors: [Theme.txt, Theme.txt.opacity(0.55)], startPoint: .leading, endPoint: .trailing))
        case .upcoming:
            Capsule().strokeBorder(Theme.txt.opacity(0.85), lineWidth: 1)
        case .downloading:
            pattern { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.txt.opacity(0.45)))
                var x: CGFloat = -size.height
                while x < size.width {
                    var stripe = Path()
                    stripe.addLines([CGPoint(x: x, y: size.height), CGPoint(x: x + 4, y: size.height),
                                     CGPoint(x: x + 4 + size.height, y: 0), CGPoint(x: x + size.height, y: 0)])
                    context.fill(stripe, with: .color(Theme.txt))
                    x += 8
                }
            }
        case .wanted:
            pattern { context, size in
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: 0, width: 3, height: size.height)), with: .color(Theme.txt.opacity(0.8)))
                    x += 6
                }
            }
        case .warning:
            pattern { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.txt.opacity(0.2)))
                var x: CGFloat = -size.height
                while x < size.width {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: size.height))
                    line.addLine(to: CGPoint(x: x + size.height, y: 0))
                    context.stroke(line, with: .color(Theme.txt), lineWidth: 1.2)
                    x += 3.5
                }
            }
        }
    }

    private func pattern(_ draw: @escaping (inout GraphicsContext, CGSize) -> Void) -> some View {
        Canvas { context, size in draw(&context, size) }.clipShape(Capsule())
    }
}
