import SwiftUI

// The login backdrops (grid, aurora, flow, web, hub, orbits, gradient,
// solid), drawn by BackdropEngine. Helpers stay private to this file.

// MARK: - Helpers

private func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double { v < a ? a : v > b ? b : v }
private func rnd() -> Double { Double.random(in: 0..<1) }

/// An sRGB colour as the canvas sees it.
struct BackdropRGB {
    let r: Double, g: Double, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        self.init(Double(hex >> 16), Double((hex >> 8) & 255), Double(hex & 255))
    }

    func color(_ alpha: Double = 1) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: alpha)
    }
}

/// `lc(a, b, t)`: a rounded linear mix of two hex colours.
private func lc(_ a: UInt32, _ b: UInt32, _ t: Double) -> BackdropRGB {
    let A = BackdropRGB(hex: a), B = BackdropRGB(hex: b)
    return BackdropRGB((A.r + (B.r - A.r) * t).rounded(), (A.g + (B.g - A.g) * t).rounded(), (A.b + (B.b - A.b) * t).rounded())
}

private let transparentBlack = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0)
private let cyan = BackdropRGB(hex: 0x22D3EE)
private let green = BackdropRGB(hex: 0x34D399)

private func dot(_ c: GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ color: Color) {
    c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
}

private func ring(_ c: GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ color: Color) {
    c.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color), lineWidth: 1)
}

private func line(_ c: GraphicsContext, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ color: Color) {
    var p = Path()
    p.move(to: CGPoint(x: x1, y: y1))
    p.addLine(to: CGPoint(x: x2, y: y2))
    c.stroke(p, with: .color(color), lineWidth: 1)
}

/// `createRadialGradient(x, y, 0, x, y, r)` from `from` to `to`, filling `shape`.
private func radial(_ c: GraphicsContext, _ shape: Path, _ x: Double, _ y: Double, _ r: Double, _ from: Color, _ to: Color) {
    c.fill(shape, with: .radialGradient(Gradient(colors: [from, to]), center: CGPoint(x: x, y: y),
                                        startRadius: 0, endRadius: r))
}

/// Per-frame probability `p` over `k` frames.
private func chance(_ p: Double, _ k: Double) -> Bool { rnd() < 1 - pow(1 - p, k) }

// MARK: - grid

final class GridFX: BackdropFX {
    struct Dot { let x: Double, y: Double, ph: Double, col: BackdropRGB }
    private var d: [Dot] = []

    init(w: Double, h: Double) {
        let g = max(16, (w / 16).rounded())
        var y = g / 2
        while y < h {
            var x = g / 2
            while x < w {
                d.append(Dot(x: x, y: y, ph: rnd() * 6.28, col: lc(0x6366F1, 0x22D3EE, x / w)))
                x += g
            }
            y += g
        }
    }

    func render(_ c: GraphicsContext, t: Double) {
        for p in d {
            dot(c, p.x, p.y, 1.6, p.col.color(0.12 + 0.12 * sin(t * 0.002 + p.ph)))
        }
    }
}

// MARK: - aurora

final class AuroraFX: BackdropFX {
    let w: Double, h: Double
    init(w: Double, h: Double) {
        self.w = w
        self.h = h
    }

    func render(_ c: GraphicsContext, t: Double) {
        let mn = min(w, h)
        func blob(_ x: Double, _ y: Double, _ r: Double, _ col: Color) {
            radial(c, Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), x, y, r, col, transparentBlack)
        }
        blob(w * 0.32 + sin(t * 0.0006) * w * 0.08, h * 0.36 + cos(t * 0.0005) * h * 0.12, mn * 0.72,
             BackdropRGB(99, 102, 241).color(0.5))
        blob(w * 0.7 + cos(t * 0.0007) * w * 0.08, h * 0.66 + sin(t * 0.0006) * h * 0.12, mn * 0.66,
             BackdropRGB(34, 211, 238).color(0.45))
    }
}

// MARK: - flow

/// Packets ride lanes into a shelf that lights green: clamp(h/95, 4, 8) lanes,
/// packets 2–3.3px at speed 1.4–3.0, shelf blocks 20×12 at the right edge.
final class FlowFX: BackdropFX {
    struct Packet { let l: Int; var x: Double; let sp: Double; let r: Double }
    let w: Double, h: Double
    private var lanes: [Double] = []
    private var pk: [Packet] = []
    private var next: Double = 0
    private var shelf: [Double]

    init(w: Double, h: Double) {
        self.w = w
        self.h = h
        let n = Int(clamp((h / 95).rounded(), 4, 8))
        for i in 0..<n { lanes.append(Double(i + 1) / Double(n + 1) * h) }
        shelf = Array(repeating: 0, count: Int(clamp((h / 26).rounded(), 8, 26)))
    }

    private var rx: Double { w - 46 }

    func step(t: Double, k: Double) {
        if t >= next && pk.count < 26 {
            pk.append(Packet(l: Int(rnd() * Double(lanes.count)), x: -10, sp: 1.4 + rnd() * 1.6, r: 2 + rnd() * 1.3))
            next = t + 150 + rnd() * 260
        }
        for i in pk.indices.reversed() {
            pk[i].x += pk[i].sp * k
            if pk[i].x >= rx {
                shelf[Int(rnd() * Double(shelf.count))] = t
                pk.remove(at: i)
            }
        }
    }

    func render(_ c: GraphicsContext, t: Double) {
        let laneColor = BackdropRGB(120, 150, 250).color(0.07)
        for y in lanes { line(c, 0, y, rx, y, laneColor) }
        for p in pk {
            let y = lanes[p.l]
            dot(c, p.x, y, p.r, cyan.color(0.85))
            dot(c, p.x - 6, y, p.r * 0.8, cyan.color(0.2))
        }
        let idle = BackdropRGB(hex: 0x2A3350)
        for i in shelf.indices {
            let y = (Double(i) + 0.5) / Double(shelf.count) * h
            let lit = shelf[i] != 0 && t - shelf[i] < 1400 ? 1 - (t - shelf[i]) / 1400 : 0
            c.fill(Path(CGRect(x: rx + 6, y: y - 6, width: 20, height: 12)),
                   with: .color((lit > 0 ? green : idle).color(0.13 + lit * 0.6)))
        }
    }
}

// MARK: - web

final class WebFX: BackdropFX {
    struct Node { var x: Double, y: Double, vx: Double, vy: Double; let col: BackdropRGB; var res: Double }
    struct Pulse { let a: Int, b: Int; let t: Double, d: Double }
    let w: Double, h: Double
    private var nd: [Node] = []
    private var pulses: [Pulse] = []
    private var next: Double = 0

    init(w: Double, h: Double) {
        self.w = w
        self.h = h
        let n = Int(clamp((w * h / 9000).rounded(), 14, 90))
        for _ in 0..<n {
            nd.append(Node(x: rnd() * w, y: rnd() * h, vx: (rnd() * 2 - 1) * 0.15, vy: (rnd() * 2 - 1) * 0.15,
                           col: lc(0x818CF8, 0x22D3EE, rnd()), res: 0))
        }
    }

    private var md: Double { min(w, h) * 0.22 }

    func step(t: Double, k: Double) {
        for i in nd.indices {
            nd[i].x += nd[i].vx * k
            nd[i].y += nd[i].vy * k
            if nd[i].x < 0 || nd[i].x > w { nd[i].vx *= -1 }
            if nd[i].y < 0 || nd[i].y > h { nd[i].vy *= -1 }
        }
        if t >= next && pulses.count < 6 {
            let si = Int(rnd() * Double(nd.count))
            var best = -1
            for j in nd.indices where j != si {
                if hypot(nd[si].x - nd[j].x, nd[si].y - nd[j].y) < md { best = j; break }
            }
            if best >= 0 { pulses.append(Pulse(a: si, b: best, t: t, d: 600)) }
            next = t + 450 + rnd() * 500
        }
        for i in pulses.indices.reversed() where (t - pulses[i].t) / pulses[i].d >= 1 {
            nd[pulses[i].b].res = t
            pulses.remove(at: i)
        }
    }

    func render(_ c: GraphicsContext, t: Double) {
        let md = self.md
        for i in nd.indices {
            for j in (i + 1)..<nd.count {
                let dx = nd[i].x - nd[j].x, dy = nd[i].y - nd[j].y, d2 = dx * dx + dy * dy
                if d2 > md * md { continue }
                let alpha = (((1 - d2.squareRoot() / md) * 0.2) * 1000).rounded() / 1000
                line(c, nd[i].x, nd[i].y, nd[j].x, nd[j].y, BackdropRGB(125, 150, 250).color(alpha))
            }
        }
        for pu in pulses {
            let na = nd[pu.a], nb = nd[pu.b], pp = (t - pu.t) / pu.d
            dot(c, na.x + (nb.x - na.x) * pp, na.y + (nb.y - na.y) * pp, 1.9, cyan.color(0.9))
        }
        for n in nd {
            let rf = n.res != 0 && t - n.res < 800 ? 1 - (t - n.res) / 800 : 0
            dot(c, n.x, n.y, rf > 0 ? 2.6 : 1.9, (rf > 0 ? green : n.col).color(clamp(0.5 + rf * 0.5, 0, 1)))
        }
    }
}

// MARK: - hub

final class HubFX: BackdropFX {
    struct Particle { var ang: Double, rad: Double; let born: Double, sp: Double; let col: BackdropRGB; var res: Double }
    let w: Double, h: Double
    private var pa: [Particle] = []

    init(w: Double, h: Double) {
        self.w = w
        self.h = h
        let n = Int(clamp((w * h / 5000).rounded(), 24, 150))
        for _ in 0..<n {
            let ang = rnd() * 6.28, rad = max(w, h) * (0.28 + rnd() * 0.5)
            pa.append(Particle(ang: ang, rad: rad, born: rad, sp: 0.25 + rnd() * 0.6,
                               col: lc(0x818CF8, 0x22D3EE, rnd()), res: 0))
        }
    }

    func step(t: Double, k: Double) {
        for i in pa.indices {
            pa[i].rad -= pa[i].sp * k
            if pa[i].rad < 8 {
                pa[i].res = t
                pa[i].rad = pa[i].born
                pa[i].ang = rnd() * 6.28
            }
        }
    }

    func render(_ c: GraphicsContext, t: Double) {
        let cx = w / 2, cy = h * 0.5
        radial(c, Path(CGRect(x: 0, y: 0, width: w, height: h)), cx, cy, w * 0.22,
               BackdropRGB(34, 211, 238).color(0.16), BackdropRGB(34, 211, 238).color(0))
        var recent = 0
        for p in pa {
            if p.res != 0 && t - p.res < 450 { recent += 1 }
            dot(c, cx + cos(p.ang) * p.rad, cy + sin(p.ang) * p.rad, 1.4, p.col.color(0.5))
        }
        if recent > 0 {
            dot(c, cx, cy, 5 + Double(recent) * 2, green.color(clamp(Double(recent) * 0.12, 0, 0.6)))
        }
        dot(c, cx, cy, 3, cyan.color())
    }
}

// MARK: - orbits

final class OrbitsFX: BackdropFX {
    struct Sat { let rad: Double; var ang: Double; let sp: Double; var done: Double }
    struct Orbit { var x: Double, y: Double, vx: Double, vy: Double; let col: BackdropRGB; var sats: [Sat] }
    let w: Double, h: Double
    private var co: [Orbit] = []

    init(w: Double, h: Double) {
        self.w = w
        self.h = h
        let n = Int(clamp((w * h / 26000).rounded(), 4, 24))
        for _ in 0..<n {
            let count = 1 + Int(rnd() * 2)
            var sats: [Sat] = []
            for k in 0..<count {
                sats.append(Sat(rad: 9 + Double(k) * 8 + rnd() * 4, ang: rnd() * 6.28,
                                sp: (0.015 + rnd() * 0.025) * (rnd() < 0.5 ? 1 : -1), done: 0))
            }
            co.append(Orbit(x: rnd() * w, y: rnd() * h, vx: (rnd() * 2 - 1) * 0.1, vy: (rnd() * 2 - 1) * 0.1,
                            col: lc(0x818CF8, 0x22D3EE, rnd()), sats: sats))
        }
    }

    func step(t: Double, k: Double) {
        for i in co.indices {
            co[i].x += co[i].vx * k
            co[i].y += co[i].vy * k
            if co[i].x < 0 || co[i].x > w { co[i].vx *= -1 }
            if co[i].y < 0 || co[i].y > h { co[i].vy *= -1 }
            for s in co[i].sats.indices {
                co[i].sats[s].ang += co[i].sats[s].sp * k
                if chance(0.003, k) { co[i].sats[s].done = t }
            }
        }
    }

    func render(_ c: GraphicsContext, t: Double) {
        for o in co {
            dot(c, o.x, o.y, 2.2, o.col.color(0.85))
            for st in o.sats {
                ring(c, o.x, o.y, st.rad, o.col.color(0.1))
                let df = st.done != 0 && t - st.done < 700 ? 1 - (t - st.done) / 700 : 0
                dot(c, o.x + cos(st.ang) * st.rad, o.y + sin(st.ang) * st.rad, 1.5,
                    (df > 0 ? green : cyan).color(clamp(0.7 + df * 0.3, 0, 1)))
            }
        }
    }
}

// MARK: - static

final class GradientFX: BackdropFX {
    let w: Double, h: Double
    init(w: Double, h: Double) {
        self.w = w
        self.h = h
    }

    func render(_ c: GraphicsContext, t: Double) {
        let all = Path(CGRect(x: 0, y: 0, width: w, height: h))
        c.fill(all, with: .linearGradient(Gradient(colors: [BackdropRGB(hex: 0x2B2F66).color(), BackdropRGB(hex: 0x123B46).color()]),
                                          startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
        radial(c, all, w * 0.5, h * 0.4, max(w, h) * 0.6, BackdropRGB(34, 211, 238).color(0.14), transparentBlack)
    }
}

final class SolidFX: BackdropFX {
    let w: Double, h: Double
    init(w: Double, h: Double) {
        self.w = w
        self.h = h
    }

    func render(_ c: GraphicsContext, t: Double) {
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(BackdropRGB(hex: 0x0F1116).color()))
    }
}

final class NoneFX: BackdropFX {
    func render(_ c: GraphicsContext, t: Double) {}
}
