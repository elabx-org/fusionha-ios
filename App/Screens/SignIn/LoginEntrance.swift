import SwiftUI
import FusionhaKit

// MARK: - Entrance choreography (Login.module.css)

enum LoginEntranceKind {
    /// `riseIn`: opacity 0, translateY(22px) scale(.985), cubic-bezier(.16, 1, .3, 1).
    case riseIn(Double)
    /// `fadeUp`: opacity 0, translateY(10px), cubic-bezier(.16, 1, .3, 1).
    case fadeUp(Double)
    /// `letterIn`: opacity 0, translateY(18px) rotate(-8deg), 0.6s cubic-bezier(.34, 1.56, .64, 1).
    case letterIn
}

/// Plays one of the login's CSS entrance keyframes the first time the view
/// appears (after `delay`, `animation-fill-mode: both`). Instant when motion is off.
struct LoginEntrance: ViewModifier {
    let kind: LoginEntranceKind
    let delay: Double
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    func body(content: Content) -> some View {
        let on = shown || !motion
        content
            .scaleEffect(on ? 1 : startScale)
            .rotationEffect(.degrees(on ? 0 : startRotation))
            .offset(y: on ? 0 : startY)
            .opacity(on ? 1 : 0)
            .onAppear {
                guard motion, !shown else { return }
                withAnimation(animation.delay(delay)) { shown = true }
            }
    }

    private var startY: CGFloat {
        switch kind {
        case .riseIn: return 22
        case .fadeUp: return 10
        case .letterIn: return 18
        }
    }

    private var startScale: CGFloat {
        if case .riseIn = kind { return 0.985 }
        return 1
    }

    private var startRotation: Double {
        if case .letterIn = kind { return -8 }
        return 0
    }

    private var animation: Animation {
        switch kind {
        case .riseIn(let d), .fadeUp(let d): return .timingCurve(0.16, 1, 0.3, 1, duration: d)
        case .letterIn: return .timingCurve(0.34, 1.56, 0.64, 1, duration: 0.6)
        }
    }
}

extension View {
    func loginEntrance(_ kind: LoginEntranceKind, delay: Double) -> some View {
        modifier(LoginEntrance(kind: kind, delay: delay))
    }
}

/// `.logoImg`: an elastic pop on entry (`logoPop` 0.9s, delay 0.12s), then a
/// slow breathe + bob at rest (`logoIdle` 4.2s ease-in-out from 1.2s, forever).
struct LoginLogo: View {
    let hero: Bool
    @Environment(\.motionEnabled) private var motion
    @State private var popped = false
    @State private var idleStart: Date?

    var body: some View {
        let size: CGFloat = hero ? 108 : 56
        TimelineView(.animation(minimumInterval: nil, paused: idleStart == nil || !motion)) { timeline in
            let pose = idlePose(at: timeline.date)
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255).opacity(hero ? 0.55 : 0.45),
                        radius: hero ? 23 : 15, y: hero ? 16 : 12)
                .scaleEffect(pose.scale)
                .offset(y: pose.y)
        }
        .scaleEffect(popped || !motion ? 1 : 0.6)
        .opacity(popped || !motion ? 1 : 0)
        .accessibilityLabel("fusionha")
        .onAppear {
            guard motion, !popped else { return }
            withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.9).delay(0.12)) { popped = true }
            idleStart = Date().addingTimeInterval(1.2)
        }
    }

    /// `logoIdle` keyframes: 0% (0, 1) · 30% (-4, 1.035) · 55% (-1, 1.01) · 100% (0, 1),
    /// each segment eased with `ease-in-out`.
    private func idlePose(at date: Date) -> (y: CGFloat, scale: CGFloat) {
        guard motion, let idleStart, date > idleStart else { return (0, 1) }
        let p = date.timeIntervalSince(idleStart).truncatingRemainder(dividingBy: 4.2) / 4.2
        let keys: [(at: Double, y: Double, s: Double)] = [(0, 0, 1), (0.3, -4, 1.035), (0.55, -1, 1.01), (1, 0, 1)]
        for i in 1..<keys.count where p <= keys[i].at {
            let a = keys[i - 1], b = keys[i]
            let e = UnitCurve.easeInOut.value(at: (p - a.at) / (b.at - a.at))
            return (CGFloat(a.y + (b.y - a.y) * e), CGFloat(a.s + (b.s - a.s) * e))
        }
        return (0, 1)
    }
}

/// `.wordmark`: "fusionha" uppercase with 0.34em tracking, each letter popping in
/// (`letterIn`, delay 0.34s + i × 0.05s); the last two letters carry the gradient.
struct LoginWordmark: View {
    let size: CGFloat
    private static let letters = "FUSIONHA".map { String($0) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.letters.indices, id: \.self) { i in
                Group {
                    if i >= 6 {
                        Text(Self.letters[i]).foregroundStyle(Theme.loginGradient)
                    } else {
                        Text(Self.letters[i]).foregroundStyle(Theme.txt)
                    }
                }
                .font(.system(size: size, weight: .semibold))
                .tracking(size * 0.34)
                .loginEntrance(.letterIn, delay: 0.34 + Double(i) * 0.05)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("fusionha")
    }
}

/// A one-column CSS grid with `min-height: 100%`: each row gets its natural
/// height and the spare height is shared equally (auto tracks stretch).
struct StretchRows: Layout {
    var minHeight: CGFloat

    private func heights(_ width: CGFloat?, _ subviews: Subviews) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width
        let total = heights(width, subviews).reduce(0, +)
        return CGSize(width: width ?? 0, height: max(minHeight, total))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = heights(bounds.width, subviews)
        let extra = subviews.isEmpty ? 0 : max(0, bounds.height - rows.reduce(0, +)) / CGFloat(subviews.count)
        var y = bounds.minY
        for (i, subview) in subviews.enumerated() {
            let height = rows[i] + extra
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height
        }
    }
}
