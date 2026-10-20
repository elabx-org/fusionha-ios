import SwiftUI
import FusionhaKit

// MARK: Row

struct TaskRow: View {
    let task: SystemTask
    let running: Bool
    let now: Date
    var child = false
    let onRun: () -> Void

    var body: some View {
        let manual = task.intervalSeconds <= 0
        let countdown = manual ? nil : SystemTaskFormat.countdown(task.nextRun, now: now)
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(SystemTaskFormat.label(task.name))
                        .font(.system(size: child ? 12.75 : 13.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    if running {
                        RunningRing()
                    } else {
                        OutcomeGlyph(result: task.lastResult)
                    }
                }
                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 6) {
                Text(running ? "Running…" : (manual ? "—" : countdown?.text ?? "—"))
                    .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(countdown?.due == true && !running ? Theme.miss : Theme.mut)
                    .contentTransition(.numericText(countsDown: true))
                Button(running ? "Running…" : "Run now", action: onRun)
                    .buttonStyle(.web(.subtle))
                    .disabled(running)
                    .accessibilityLabel("Run \(SystemTaskFormat.label(task.name)) now")
            }
            .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(.vertical, child ? 11 : 14)
    }

    private var metaLine: some View {
        var parts = [SystemTaskFormat.schedule(task.intervalSeconds),
                     "Last run \(SystemTaskFormat.lastRun(task.lastRun, now: now))"]
        if let duration = task.lastDuration { parts.append("took \(SystemTaskFormat.duration(duration))") }
        return Text(parts.joined(separator: " · "))
            .font(.system(size: 12).monospacedDigit())
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The in-flight ring; a static dot under Reduce Motion.
private struct RunningRing: View {
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var spin = false

    var body: some View {
        if motionOff {
            Circle().fill(Theme.grab).frame(width: 9, height: 9)
                .accessibilityLabel("Running")
        } else {
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Theme.grab, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .background(Circle().stroke(Theme.grab.opacity(0.28), lineWidth: 2))
                .frame(width: 11, height: 11)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
                .onAppear { spin = true }
                .accessibilityLabel("Running")
        }
    }
}

/// ✓ / ! for the last outcome, popping in with a spring.
private struct OutcomeGlyph: View {
    let result: String?
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var shown = false

    var body: some View {
        if result == "completed" || result == "failed" {
            let failed = result == "failed"
            Image(systemName: failed ? "exclamationmark" : "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(failed ? Theme.danger : Theme.done)
                .frame(width: 17, height: 17)
                .background((failed ? Theme.danger : Theme.done).opacity(0.16), in: Circle())
                .scaleEffect(shown || motionOff ? 1 : 0.6)
                .opacity(shown || motionOff ? 1 : 0)
                .onAppear {
                    withAnimation(motionOff ? nil : .spring(response: 0.25, dampingFraction: 0.6)) { shown = true }
                }
                .accessibilityLabel(failed ? "Last run failed" : "Last run completed")
        }
    }
}
