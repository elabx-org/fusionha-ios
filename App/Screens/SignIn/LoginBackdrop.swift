import SwiftUI

// The login backdrops (web components/login/backdrops.ts), ported 1:1: the same
// nine modes, shapes, counts, colours, speeds and timing constants. Each mode is
// a small reference type initialised from the canvas size like the web's
// `init(w, h)`, stepped by a `TimelineView(.animation)` and drawn on a `Canvas`.
// `t` is milliseconds, like the web's rAF timestamp. Per-frame motion (the web
// moves things "per rAF frame" at 60 Hz) is scaled by the real frame time so
// speeds match on 120 Hz displays too. Reduce Motion (or `still`) draws one
// settled frame at t = 1500 and never loops, exactly like `createBackdrop`.

enum BackdropMode: String, CaseIterable, Identifiable {
    case flow, web, hub, orbits, grid, aurora, gradient, solid, none

    var id: String { rawValue }

    /// `resolveBackground`: unknown or missing values fall back to aurora.
    init(resolving value: String?) {
        self = value.flatMap(BackdropMode.init(rawValue:)) ?? .aurora
    }

    /// `ANIMATED_MODES`.
    var animated: Bool {
        switch self {
        case .flow, .web, .hub, .orbits, .grid, .aurora: return true
        case .gradient, .solid, .none: return false
        }
    }

    /// The names in LoginCustomisePanel's `BACKGROUNDS`.
    var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// The transparent backdrop canvas (the web's `<canvas>` from `LoginBackdrop` /
/// the settings `Backdrop`). Callers put the stage colour behind it and the
/// veil over it. `animate: false` draws one still frame (settings thumbnails).
/// The loop pauses while the view is off screen or the app is inactive.
struct BackdropCanvas: View {
    let mode: BackdropMode
    var animate = true
    /// Reduce Motion or the server's `animations_enabled = false`.
    var motionOff = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var engine = BackdropEngine()
    @State private var visible = false

    private var still: Bool { !animate || reduceMotion || motionOff || !mode.animated }

    var body: some View {
        Group {
            if still {
                Canvas { context, size in
                    engine.prepare(mode: mode, size: size, still: true)
                    engine.render(context, at: .now)
                }
            } else {
                TimelineView(.animation(minimumInterval: nil, paused: !visible || scenePhase != .active)) { timeline in
                    Canvas { context, size in
                        engine.prepare(mode: mode, size: size, still: false)
                        engine.render(context, at: timeline.date)
                    }
                }
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Engine

/// Owns the current effect, its size and the clock (`createBackdrop`).
final class BackdropEngine {
    static let stillT: Double = 1500

    private var mode: BackdropMode?
    private var size: CGSize = .zero
    private var still = false
    private var fx: BackdropFX?
    private var start: Date?
    private var lastT: Double = -1

    func prepare(mode: BackdropMode, size: CGSize, still: Bool) {
        let w = max(1, size.width.rounded()), h = max(1, size.height.rounded())
        let rounded = CGSize(width: w, height: h)
        guard fx == nil || mode != self.mode || rounded != self.size || still != self.still else { return }
        self.mode = mode
        self.size = rounded
        self.still = still
        let fx = makeFX(mode, w: Double(w), h: Double(h))
        self.fx = fx
        start = nil
        lastT = -1
        if still { fx.step(t: Self.stillT, k: 1) }
    }

    func render(_ context: GraphicsContext, at date: Date) {
        guard let fx else { return }
        if still {
            fx.render(context, t: Self.stillT)
            return
        }
        // Like performance.now(): starts just after zero when the loop starts.
        let origin = start ?? date.addingTimeInterval(-1.0 / 60)
        start = origin
        let t = date.timeIntervalSince(origin) * 1000
        if t > lastT {
            // One web frame = 1/60 s; a long gap (paused) never jumps more than 3.
            let k = lastT < 0 ? 1 : min((t - lastT) / (1000.0 / 60), 3)
            fx.step(t: t, k: k)
            lastT = t
        }
        fx.render(context, t: lastT)
    }

    private func makeFX(_ mode: BackdropMode, w: Double, h: Double) -> BackdropFX {
        switch mode {
        case .grid: return GridFX(w: w, h: h)
        case .aurora: return AuroraFX(w: w, h: h)
        case .flow: return FlowFX(w: w, h: h)
        case .web: return WebFX(w: w, h: h)
        case .hub: return HubFX(w: w, h: h)
        case .orbits: return OrbitsFX(w: w, h: h)
        case .gradient: return GradientFX(w: w, h: h)
        case .solid: return SolidFX(w: w, h: h)
        case .none: return NoneFX()
        }
    }
}

/// One effect. `step` is the state half of the web's `draw` (movement, spawns,
/// timers), `render` the painting half, so a re-render never advances time.
protocol BackdropFX: AnyObject {
    func step(t: Double, k: Double)
    func render(_ c: GraphicsContext, t: Double)
}

extension BackdropFX {
    func step(t: Double, k: Double) {}
}

// MARK: - Stage + veil

/// An elliptical CSS `radial-gradient(rx ry at cx cy, …)` painted on a Canvas
/// (SwiftUI's gradients are circular or frame-proportional).
struct CSSRadialGradient: View {
    /// Radii and centre as fractions of the box (CSS percentages).
    let rx: Double, ry: Double, cx: Double, cy: Double
    let stops: [Gradient.Stop]

    var body: some View {
        Canvas { context, size in
            let w = Double(size.width), h = Double(size.height)
            let radiusX = max(rx * w, 1), radiusY = max(ry * h, 1)
            var c = context
            c.translateBy(x: cx * w, y: cy * h)
            c.scaleBy(x: 1, y: radiusY / radiusX)
            let span = max(w, h) * 4
            c.fill(Path(CGRect(x: -span, y: -span, width: span * 2, height: span * 2)),
                   with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: radiusX))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension CSSRadialGradient {
    /// `.stage`: radial-gradient(120% 120% at 50% 0%, #101423, #07080c).
    static var stage: CSSRadialGradient {
        CSSRadialGradient(rx: 1.2, ry: 1.2, cx: 0.5, cy: 0,
                          stops: [.init(color: Color(hex: 0x101423), location: 0),
                                  .init(color: Color(hex: 0x07080C), location: 1)])
    }

    /// `.veil`: radial-gradient(120% 90% at 50% 30%, transparent 40%, rgba(0,0,0,.55) 100%).
    static var veil: CSSRadialGradient {
        CSSRadialGradient(rx: 1.2, ry: 0.9, cx: 0.5, cy: 0.3,
                          stops: [.init(color: .black.opacity(0), location: 0.4),
                                  .init(color: .black.opacity(0.55), location: 1)])
    }

    /// The settings preview's `.pvVeil` (transparent 45%, rgba(0,0,0,.5)).
    static var previewVeil: CSSRadialGradient {
        CSSRadialGradient(rx: 1.2, ry: 0.9, cx: 0.5, cy: 0.3,
                          stops: [.init(color: .black.opacity(0), location: 0.45),
                                  .init(color: .black.opacity(0.5), location: 1)])
    }
}

/// The login's backdrop layer: the chosen canvas plus the edge veil. The stage
/// colour sits behind it (SignInView).
struct LoginBackdrop: View {
    let mode: BackdropMode
    var motionOff = false

    var body: some View {
        ZStack {
            BackdropCanvas(mode: mode, motionOff: motionOff)
            CSSRadialGradient.veil
        }
    }
}
