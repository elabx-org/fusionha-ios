import SwiftUI
import FusionhaKit

/// The min · preferred · max bar on a 0–280 MB/min axis. Each handle drags
/// (min ≤ preferred ≤ max is kept), max dragged to the end becomes unlimited
/// (∞), and VoiceOver adjusts each handle by 1 MB/min.
struct QualityDefinitionRangeBar: View {
    let label: String
    @Binding var range: QualitySizeRange
    @Binding var dragging: Bool
    let onEnd: () -> Void

    private static let handle: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width - Self.handle, 1)
            let mid = geo.size.height / 2
            ZStack(alignment: .topLeading) {
                Capsule().fill(Theme.panel2)
                    .frame(width: width, height: 6)
                    .position(x: geo.size.width / 2, y: mid)
                Capsule().fill(Theme.i1.opacity(0.55))
                    .frame(width: max(0, x(maxValue, width) - x(range.min, width)), height: 6)
                    .position(x: Self.handle / 2 + (x(range.min, width) + x(maxValue, width)) / 2, y: mid)
                knob(.min, value: range.min, width: width, mid: mid)
                knob(.pref, value: range.pref, width: width, mid: mid)
                knob(.max, value: maxValue, width: width, mid: mid)
                if range.unlimited {
                    Text("∞").font(.caption.weight(.bold)).foregroundStyle(Theme.i2)
                        .position(x: geo.size.width - Self.handle / 2, y: mid - 16)
                        .accessibilityHidden(true)
                }
            }
            .coordinateSpace(.named("qd-bar"))
        }
        .frame(height: 36)
    }

    private var maxValue: Double { range.unlimited ? QualitySizeLimits.axisMax : range.max }

    /// Offset of a value along the track (out-of-axis values clamp).
    private func x(_ v: Double, _ width: CGFloat) -> CGFloat {
        CGFloat(min(max(v / QualitySizeLimits.axisMax, 0), 1)) * width
    }

    private func knob(_ h: QualitySizeLimits.Handle, value: Double, width: CGFloat, mid: CGFloat) -> some View {
        let pref = h == .pref
        return Circle()
            .fill(pref ? Theme.i1 : Theme.txt)
            .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
            .frame(width: pref ? 18 : Self.handle, height: pref ? 18 : Self.handle)
            .contentShape(Circle().inset(by: -8))
            .position(x: Self.handle / 2 + x(value, width), y: mid)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("qd-bar"))
                    .onChanged { g in
                        dragging = true
                        let raw = Double((g.location.x - Self.handle / 2) / width) * QualitySizeLimits.axisMax
                        range = QualitySizeLimits.constrain(range, h, raw)
                    }
                    .onEnded { _ in
                        dragging = false
                        onEnd()
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("\(label) \(name(h)) size")
            .accessibilityValue(accessibilityValue(h))
            .accessibilityAdjustableAction { direction in
                let current = h == .min ? range.min : (h == .pref ? range.pref : maxValue)
                let delta: Double = direction == .increment ? 1 : -1
                range = QualitySizeLimits.constrain(range, h, current + delta)
                onEnd()
            }
    }

    private func name(_ h: QualitySizeLimits.Handle) -> String {
        switch h {
        case .min: return "minimum"
        case .pref: return "preferred"
        case .max: return "maximum"
        }
    }

    private func accessibilityValue(_ h: QualitySizeLimits.Handle) -> String {
        switch h {
        case .min: return "\(Int(range.min.rounded())) MB per minute"
        case .pref: return "\(Int(range.pref.rounded())) MB per minute"
        case .max: return range.unlimited ? "unlimited" : "\(Int(range.max.rounded())) MB per minute"
        }
    }
}
