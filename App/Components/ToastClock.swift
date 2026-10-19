import SwiftUI
import Observation
import FusionhaKit

/// A toast's action button (web `ToastAction`): its label and what it does.
/// Tapping it also dismisses the toast.
struct ToastAction {
    let label: String
    let handler: @MainActor () -> Void
}

/// The toasts' auto-dismiss clocks (web `ToastCard`'s timer). A toast's clock
/// stops while it is held, by a finger on it or by VoiceOver's focus, so the
/// timer bar and the dismissal pause together, like the web's hover pause.
@MainActor
@Observable
final class ToastClock {
    /// What's left of each toast's time, 1 → 0 (the timer bar).
    private(set) var remaining: [UUID: Double] = [:]
    /// Who is holding each toast ("press", "voiceover").
    private var holds: [UUID: Set<String>] = [:]

    func hold(_ id: UUID, by holder: String, _ on: Bool) {
        if on { holds[id, default: []].insert(holder) } else { holds[id]?.remove(holder) }
    }

    /// Counts the toast down, held time excluded; returns once it has run
    /// out or `alive` says it has gone.
    func run(_ id: UUID, duration: Double, alive: @MainActor () -> Bool) async {
        var countdown = ToastCountdown(duration: duration)
        remaining[id] = countdown.fraction
        while !countdown.expired, alive() {
            try? await Task.sleep(for: .seconds(ToastCountdown.tick))
            countdown.advance(ToastCountdown.tick, held: !(holds[id]?.isEmpty ?? true))
            remaining[id] = countdown.fraction
        }
        remaining[id] = nil
        holds[id] = nil
    }
}
