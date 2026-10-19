import SwiftUI
import FusionhaKit

/// A login-layout tile (`.lopt`): a tiny wireframe, the name and a line.
struct LayoutTile: View {
    let key: String
    let name: String
    let desc: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                wire
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text(desc).font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .modifier(SelectedRing(selected: selected))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var wire: some View {
        ZStack {
            Theme.panel2
            if key == "living" {
                LivingDots(spacing: 5, radius: 0.6, alpha: 0.35)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Color.white.opacity(0.14).frame(width: 74 * 0.44)
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(stops: [.init(color: Color(hex: 0x3B82F6), location: 0),
                                                 .init(color: Color(hex: 0xC256B9), location: 0.6),
                                                 .init(color: Color(hex: 0xFDBA61), location: 1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 14, height: 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 74 * 0.18)
            } else if key == "split" {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack(alignment: .trailing) {
                        Color.white.opacity(0.14)
                        RoundedRectangle(cornerRadius: 2).fill(Theme.i2.opacity(0.35))
                            .frame(width: 26, height: 5)
                            .padding(.trailing, 4)
                    }
                    .frame(width: 74 * 0.38)
                }
            } else {
                RoundedRectangle(cornerRadius: 2).fill(Theme.i2.opacity(0.28)).frame(width: 34, height: 24)
            }
        }
        .frame(width: 74, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.14)))
    }
}

/// A background option (`.opt`): a 92pt live thumbnail of the backdrop, its
/// name and an Animated/Static tag; the chosen one gets the ring and check.
/// Only the chosen thumbnail animates (the web also animates the hovered one),
/// the rest draw one still frame, so the panel never runs nine loops.
struct BackgroundTile: View {
    let mode: BackdropMode
    let selected: Bool
    let motionOff: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    Theme.panel
                    BackdropCanvas(mode: mode, animate: selected, motionOff: motionOff)
                }
                .frame(height: 92)
                .clipped()
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                HStack {
                    Text(mode.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    Spacer(minLength: 4)
                    Text(mode.animated ? "Animated" : "Static")
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(mode.animated ? Theme.i2 : Theme.dim)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(mode.animated ? Theme.i2.opacity(0.4) : Theme.line))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 20, height: 20)
                        .background(Theme.primary, in: Circle())
                        .padding(8)
                }
            }
            .modifier(SelectedRing(selected: selected))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.name), \(mode.animated ? "animated" : "static")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// `[aria-checked='true']`: an `--i2` border plus a 3pt 22% ring; else `--line`.
struct SelectedRing: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(selected ? Theme.i2 : Theme.line))
            .background(
                RoundedRectangle(cornerRadius: Theme.radius + 3, style: .continuous)
                    .fill(Theme.i2.opacity(selected ? 0.22 : 0))
                    .padding(-3))
    }
}

/// The Living logo's dot field in miniature (`.pvDots` / `.liv`): a grid of
/// faint periwinkle dots on #08090d.
struct LivingDots: View {
    let spacing: CGFloat
    let radius: CGFloat
    let alpha: Double

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x08090D)))
            let dot = Color(red: 170 / 255, green: 180 / 255, blue: 1).opacity(alpha)
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(dot))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

/// `.pvMark`: the logo at 54pt, floating (`pvFloat` 3.6s: up 3pt and a 10° turn at the midpoint).
struct FloatingMark: View {
    let motionOff: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: motionOff)) { context in
            let phase = motionOff ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6
            let k = UnitCurve.easeInOut.value(at: phase < 0.5 ? phase * 2 : (1 - phase) * 2)
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .rotation3DEffect(.degrees(10 * k), axis: (x: 0, y: 1, z: 0))
                .offset(y: -3 * k)
        }
    }
}
