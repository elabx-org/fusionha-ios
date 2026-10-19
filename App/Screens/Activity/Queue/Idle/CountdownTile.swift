import SwiftUI
import FusionhaKit

/// A scheduled run counting down from its `next_run` (web `CountdownTile`):
/// under an hour a ticking `m:ss` clock, past an hour a calm `in 11h 15m`,
/// "Syncing…" with a sweep while it runs. Ticks once a second.
struct CountdownTile: View {
    let task: IdleSummary.Task?
    let icon: String
    let label: String
    /// The span the ring fills over (the RSS interval; the last hour for search).
    let windowSeconds: Double
    let sub: String
    let runText: String
    let runSub: String
    var compact = false
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        if let task {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                live(task, now: context.date)
            }
        } else {
            ReadinessTile(icon: icon, label: label, compact: compact) {
                ReadinessValue(value: "—", compact: compact)
                ReadinessCaption(text: "not scheduled")
            }
        }
    }

    private func live(_ task: IdleSummary.Task, now: Date) -> some View {
        let cd = IdleTime.countdown(to: task.nextRunDate, now: now)
        let running = task.running || cd.due
        let state = IdleTime.tileState(running: task.running, cd)
        let ticking = !running && cd.seconds < 3600
        return ReadinessTile(icon: icon, label: label, state: state, compact: compact) {
            HStack(spacing: 9) {
                CountdownRing(fraction: IdleTime.ringFraction(target: task.nextRunDate, now: now, windowSeconds: windowSeconds),
                              color: state.color)
                clock(running ? runText : (ticking ? String(cd.text.dropFirst(3)) : cd.text),
                      running: running, ticking: ticking)
            }
            .padding(.top, 6)
            if running { CountdownSweep().padding(.top, 8) }
            ReadinessCaption(text: running ? runSub : sub)
        }
        .accessibilityLabel("\(label), \(running ? runText : cd.text)")
    }

    private func clock(_ text: String, running: Bool, ticking: Bool) -> some View {
        Text(text)
            .font(.system(size: running || !ticking ? (compact ? 13.5 : 15) : (compact ? 17 : 20),
                          weight: .heavy, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(running ? Theme.grab : Theme.txt)
            .contentTransition(.numericText(countsDown: true))
            .animation(reduce ? nil : .easeOut(duration: 0.25), value: text)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// The 28 pt progress ring with the live dot in its middle.
private struct CountdownRing: View {
    let fraction: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(Theme.txt.opacity(0.1), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            ActPulseDot(color: color, size: 10, spread: 8, duration: 2)
        }
        .frame(width: 25, height: 25)
        .padding(1.5)
        .accessibilityHidden(true)
    }
}

/// The running sweep: a solid band crossing a faint track (static under Reduce Motion).
private struct CountdownSweep: View {
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        GeometryReader { proxy in
            let band = proxy.size.width * 0.4
            Capsule().fill(Theme.grab.opacity(0.15))
                .overlay(alignment: .leading) {
                    if reduce {
                        Capsule().fill(Theme.grab).frame(width: band)
                    } else {
                        RepeatForever(animation: .easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { on in
                            Capsule().fill(Theme.grab).frame(width: band)
                                .offset(x: on ? proxy.size.width : -band)
                        }
                    }
                }
                .clipShape(Capsule())
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}
