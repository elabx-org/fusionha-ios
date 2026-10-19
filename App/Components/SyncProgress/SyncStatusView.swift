import SwiftUI
import FusionhaKit

// Sync progress (fusionha 0.4.215, web `components/sync-progress/`): one
// source's state line with its dot, and the thin bar while it runs. Status is
// the dot's colour, never a border. Motion stops under Reduce Motion.

extension SyncVariant {
    /// Web `SYNC_COLOR`: running = grabbing, error = danger, paused = dim, idle = done.
    var color: Color {
        switch self {
        case .running: return Theme.grab
        case .error: return Theme.danger
        case .paused: return Theme.dim
        case .idle: return Theme.done
        }
    }
}

extension SyncLine {
    /// The line as one `Text`, bold runs in the primary text colour.
    var text: Text {
        segments.reduce(Text("")) { line, part in
            line + (part.bold ? Text(part.text).fontWeight(.bold).foregroundColor(Theme.txt) : Text(part.text))
        }
    }
}

/// "Checking 24 of 38 · 6 requested so far" / "Up to date · checked 3 min ago
/// · next check in 12 hr" / the error or paused reason, plus the bar while
/// it runs (web `SyncStatus`).
struct SyncStatusView: View {
    let sync: SourceSync?
    var requested = 0
    var lastCheckedAt: String? = nil
    var nextCheckAt: String? = nil
    var lastError: String? = nil
    var errorLead = "Couldn’t read this source"
    var paused = false
    var pausedText: String? = nil
    var note: String? = nil
    var barLabel = "Sync progress"

    private var variant: SyncVariant { SyncProgress.variant(sync, paused: paused) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                SyncDot(color: variant.color, live: variant == .running)
                    .padding(.top, 4.5)
                SyncProgress.line(sync, requested: requested, lastCheckedAt: lastCheckedAt, nextCheckAt: nextCheckAt,
                                  lastError: lastError, errorLead: errorLead, paused: paused,
                                  pausedText: pausedText, note: note).text
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            if variant == .running {
                SyncBar(sync: sync, label: barLabel)
            }
        }
        .onChange(of: variant) { _, next in
            // Announce the state, never the count that moves every 2 s.
            let words = SyncProgress.announcement(next, lastCheckedAt: lastCheckedAt, note: note, errorLead: errorLead)
            AccessibilityNotification.Announcement(words).post()
        }
    }
}

/// The 7 pt state dot; it pulses while live (still under Reduce Motion).
struct SyncDot: View {
    let color: Color
    var live = false
    @Environment(\.accessibilityReduceMotion) private var systemReduce
    @Environment(\.actReduceMotion) private var appReduce

    var body: some View {
        Group {
            if live {
                ActPulseDot(color: color, size: 7, spread: 6)
            } else {
                Circle().fill(color).frame(width: 7, height: 7)
            }
        }
        .environment(\.actReduceMotion, systemReduce || appReduce)
        .accessibilityHidden(true)
    }
}

/// The thin progress bar: the accent gradient (web `--grad`), easing to the
/// new width with a light sweep while live; full width until the total is known.
struct SyncBar: View {
    let sync: SourceSync?
    let label: String
    @Environment(\.accessibilityReduceMotion) private var systemReduce
    @Environment(\.actReduceMotion) private var appReduce

    var body: some View {
        let pct = SyncProgress.percent(sync)
        ActProgressBar(fraction: Double(pct ?? 100) / 100, height: 5, fill: AnyShapeStyle(Theme.fusion), shimmer: true)
            .environment(\.actReduceMotion, systemReduce || appReduce)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }

    private var value: String {
        guard let total = sync?.total else { return "Reading" }
        return "\(sync?.checked ?? 0) of \(total)"
    }
}
