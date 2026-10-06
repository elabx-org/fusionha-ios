import SwiftUI

/// Holds back new artwork loads while a fast jump is in progress (an A–Z
/// scrub), so each jump paints the grid's silhouette at once (card frames,
/// titles, version chips) and only the rows the finger rests on start
/// downloading and decoding posters. Cached art is never held.
@MainActor
final class ArtLoadGate {
    /// How long the jumps must pause before held loads start.
    static let settle: TimeInterval = 0.1

    private var active = false
    private var lastJump = Date.distantPast

    /// True while jumping, until the jumps pause for `settle`.
    var held: Bool { active && Date().timeIntervalSince(lastJump) < Self.settle }

    /// A drag that jumps started (`active`) or a jump landed.
    func jumped() {
        active = true
        lastJump = Date()
    }

    /// The drag ended: everything loads.
    func release() { active = false }

    /// Returns once loads may start (or when the task is cancelled).
    func wait() async {
        while held {
            try? await Task.sleep(for: .milliseconds(40))
            if Task.isCancelled { return }
        }
    }
}

private struct ArtLoadGateKey: EnvironmentKey {
    static let defaultValue: ArtLoadGate? = nil
}

extension EnvironmentValues {
    /// The gate `PosterImage` waits on before a network/decode load; nil loads at once.
    var artLoadGate: ArtLoadGate? {
        get { self[ArtLoadGateKey.self] }
        set { self[ArtLoadGateKey.self] = newValue }
    }
}
