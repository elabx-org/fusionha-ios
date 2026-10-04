import SwiftUI
import FusionhaKit

/// "When to grab it" (web `ReleaseTimeline`): minimum availability on a rail —
/// Announced / In cinemas / Released, evenly spaced, with an amber TODAY pill
/// placed by date. The fill runs from the chosen stop to the end; stops after it
/// are lit dots. The caption says when searching starts; "Why?" says why.
struct GrabTimeline: View {
    let timeline: ReleaseTimelineModel
    let value: String
    let onChange: (String) -> Void
    @State private var why = false
    @Environment(\.motionEnabled) private var motion

    /// Today's pill keeps this far from a track edge, and from a knob.
    private static let edge: CGFloat = 26
    private static let knob: CGFloat = 38

    private var selectedIndex: Int { timeline.stops.firstIndex { $0.key == value } ?? 0 }

    var body: some View {
        let selected = timeline.stops[selectedIndex]
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geo in
                    let width = geo.size.width
                    ZStack(alignment: .topLeading) {
                        Capsule().fill(Theme.txt.opacity(0.08))
                            .frame(height: 6)
                            .offset(y: 16)
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.i1, Theme.i2], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: Theme.i2.opacity(0.35), radius: 7)
                            .frame(width: max(0, width * (1 - selected.pos / 100)), height: 6)
                            .offset(x: width * selected.pos / 100, y: 16)
                        if let today = timeline.today {
                            Text("TODAY")
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                .tracking(0.76)
                                .foregroundStyle(Color(hex: 0x1A1204))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Theme.miss, in: Capsule())
                                .background(Capsule().strokeBorder(Theme.card, lineWidth: 3).padding(-3))
                                .fixedSize()
                                .position(x: todayX(today, width: width), y: 19)
                                .zIndex(2)
                                .accessibilityHidden(true)
                        }
                        ForEach(Array(timeline.stops.enumerated()), id: \.element.key) { index, stop in
                            stopButton(stop, index: index)
                                .position(x: width * stop.pos / 100, y: 39)
                        }
                    }
                }
                .frame(height: 78)
                .padding(.horizontal, 6)
                .animation(motion ? .timingCurve(0.22, 1, 0.36, 1, duration: 0.45) : nil, value: value)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    AddSummaryText(parts: ReleaseTimelineModel.caption(selected))
                        .font(.system(size: 12.5))
                    Spacer(minLength: 0)
                    Button(why ? "Hide" : "Why?") {
                        withAnimation(motion ? .easeOut(duration: 0.2) : nil) { why.toggle() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.i2)
                    .buttonStyle(.plain)
                    .frame(minHeight: 32)
                }
                .padding(.top, 12)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                .padding(.top, 6)
            }
            .padding(.horizontal, 14)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
            if why {
                AddSummaryText(parts: ReleaseTimelineModel.grabNote(selected))
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    /// Today's spot, clamped clear of the knobs either side and the track ends.
    private func todayX(_ pos: Double, width: CGFloat) -> CGFloat {
        let bounds = ReleaseTimelineModel.todayBounds(pos)
        let lo = bounds.lo.map { width * $0 / 100 + Self.knob } ?? Self.edge
        let hi = bounds.hi.map { width * $0 / 100 - Self.knob } ?? width - Self.edge
        let at = width * pos / 100
        // CSS clamp(): when the bounds cross, the lower one wins (the web's rule).
        return max(lo, min(at, hi))
    }

    private func stopButton(_ stop: TimelineStop, index: Int) -> some View {
        let chosen = index == selectedIndex
        let after = index > selectedIndex
        return Button { onChange(stop.key) } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(chosen ? Color.white : after ? Theme.i2 : Theme.panel2)
                    .overlay(Circle().strokeBorder(chosen ? Theme.i2 : after ? Theme.i2 : Theme.txt.opacity(0.22),
                                                   lineWidth: chosen ? 5 : 2))
                    .frame(width: 20, height: 20)
                    .background {
                        if chosen {
                            Circle().fill(Theme.i2.opacity(0.18)).padding(-5)
                                .shadow(color: Theme.i2.opacity(0.5), radius: 9)
                        }
                    }
                    .scaleEffect(chosen ? 1.25 : after ? 0.7 : 1)
                Text(stop.label)
                    .font(.system(size: 12.5, weight: chosen ? .bold : .semibold))
                    .foregroundStyle(chosen ? Theme.txt : Theme.mut)
                    .lineLimit(1)
                    .padding(.top, 6)
                if let dateBody = stop.dateBody {
                    (stop.estimated ? Text("est. ").italic() + Text(dateBody) : Text(dateBody))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .lineLimit(1)
                }
            }
            .padding(.top, 9)
            .padding(.bottom, 4)
            .frame(width: 92, height: 78, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stop.dateText.map { "\(stop.label), \($0)" } ?? stop.label)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
