import SwiftUI
import FusionhaKit

/// Runs the split handle's snap (the mock's spring, `DuoSeam.stiffness` and
/// `DuoSeam.dampingRatio`) as one SwiftUI animation: the seam is set to its
/// target once and SwiftUI moves the two columns on the display's frames,
/// so nothing is laid out or re-rendered per frame (build 774 stepped it on
/// an 8 ms timer and re-rendered the shell at every step; measured on the
/// v2open perf harness, `perf/v2-open`).
@MainActor
final class V2SeamSpring {
    /// Bumped by every run and cancel: a stale animation's completion is dropped.
    private var generation = 0
    private(set) var isRunning = false

    /// A new touch caught the seam: whatever was running never reports done.
    func cancel() {
        generation += 1
        isRunning = false
    }

    /// Springs from `x` (moving at `velocity`, points per second) to
    /// `target` by handing `target` to `step` inside the animation, then
    /// runs `done` once it has landed. `deferred`: start on the next run
    /// loop turn, so a seam placed at `x` this update is on screen first.
    func run(from x: Double, velocity: Double, to target: Double, dampingRatio: Double, deferred: Bool = false,
             step: @escaping @MainActor (Double) -> Void, done: @escaping @MainActor () -> Void) {
        cancel()
        let id = generation
        isRunning = true
        let distance = target - x
        let relative = abs(distance) > 0.5 ? velocity / distance : 0
        let stiffness = DuoSeam.stiffness
        let animation = Animation.interpolatingSpring(mass: 1, stiffness: stiffness,
                                                      damping: 2 * stiffness.squareRoot() * dampingRatio,
                                                      initialVelocity: relative)
        let go = { [weak self] in
            guard let self, self.generation == id else { return }
            withAnimation(animation) { step(target) } completion: { [weak self] in
                guard let self, self.generation == id else { return }
                self.isRunning = false
                done()
            }
        }
        if deferred {
            DispatchQueue.main.async { go() }
        } else {
            go()
        }
    }
}
