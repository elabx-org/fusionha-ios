import SwiftUI
import FusionhaKit

/// The hero's round status icon (`.hicon`). When the queue has just emptied it
/// pops once with a ring bursting out (the web's `pop` + `burst`); under Reduce
/// Motion it stays still and the view only crossfades in.
struct QueueClearIcon: View {
    let ready: Bool
    var size: CGFloat = 48
    var celebrate = false
    @Environment(\.actReduceMotion) private var reduce
    @State private var tick = 0

    private struct Burst { var scale: CGFloat = 0.5; var opacity: Double = 0 }

    var body: some View {
        let tone = ready ? Theme.done : Theme.miss
        Image(systemName: ready ? "checkmark" : "exclamationmark")
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(tone)
            .symbolEffect(.bounce.up, value: tick)
            .frame(width: size, height: size)
            .background(tone.opacity(0.14), in: Circle())
            .overlay {
                Circle().strokeBorder(tone, lineWidth: 2)
                    .keyframeAnimator(initialValue: Burst(), trigger: tick) { view, v in
                        view.scaleEffect(v.scale).opacity(v.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            LinearKeyframe(0.5, duration: 0.01)
                            CubicKeyframe(1.8, duration: 0.6)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(0.9, duration: 0.01)
                            CubicKeyframe(0, duration: 0.6)
                        }
                    }
            }
            .accessibilityHidden(true)
            .onAppear { if celebrate && !reduce { tick += 1 } }
    }
}

/// "All systems ready" / "Needs a look" with its live dot (`.ready`).
struct QueueClearReadyBadge: View {
    let summary: IdleSummary

    var body: some View {
        let tone = summary.isReady ? Theme.done : Theme.miss
        HStack(spacing: 6) {
            ActPulseDot(color: tone, size: 6, spread: 7, duration: 2.4)
            Text(summary.readinessLabel)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.2)
                .foregroundStyle(tone)
                .lineLimit(1)
        }
    }
}

/// "Queue clear" plus the ready badge, wrapping when narrow (`.htitle`).
struct QueueClearTitle: View {
    let summary: IdleSummary?
    var size: CGFloat = 19

    var body: some View {
        ActFlow(spacing: size > 17 ? 10 : 8, lineSpacing: 4) {
            Text("Queue clear")
                .font(.system(size: size, weight: .heavy))
                .tracking(-0.01 * size)
                .foregroundStyle(Theme.txt)
                .accessibilityAddTraits(.isHeader)
            if let summary { QueueClearReadyBadge(summary: summary).frame(minHeight: size * 1.2) }
        }
    }
}

/// The desktop hero's sub line (`.hsub`, hidden on the phone strip).
struct QueueClearSubLine: View {
    let summary: IdleSummary?
    let failed: Bool
    let episodes: Int?

    var body: some View {
        Group {
            if let s = summary { line(s) } else {
                Text(failed ? "Readiness is unavailable right now." : "Checking clients, indexers and disk…")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.mut)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ s: IdleSummary) -> Text {
        var text = bold("\(s.clients.enabled) of \(s.clients.total)") + Text(" download clients enabled, ")
            + bold("\(s.indexers.healthy) of \(s.indexers.total)") + Text(" indexers healthy")
        if let disk = s.disk { text = text + Text(", ") + bold(ActFmt.bytes(Double(disk.freeBytes))) + Text(" free") }
        if let episodes {
            text = text + (episodes > 0
                ? Text(" — ") + bold(episodes == 1 ? "1 episode" : "\(episodes) episodes") + Text(" air in the next 48h.")
                : Text(" — nothing airs in the next 48h."))
        }
        return text
    }

    private func bold(_ s: String) -> Text { Text(s).fontWeight(.semibold).foregroundColor(Theme.txt) }
}

/// The optional playful line (`.quip`), shown only when `voice_playful` is on.
struct QueueClearQuip: View {
    let seed: String
    var compact = false

    var body: some View {
        (Text("— ").foregroundColor(Theme.dim.opacity(0.6))
         + Text(VoiceQuip.mediaSuffix(kind: .series, title: seed, outcome: .grabbed)).italic().foregroundColor(Theme.dim))
            .font(.system(size: compact ? 11 : 12))
            .lineLimit(compact ? 1 : nil)
            .truncationMode(.tail)
    }
}
