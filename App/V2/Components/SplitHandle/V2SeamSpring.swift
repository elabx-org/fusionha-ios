import Foundation
import FusionhaKit

/// Runs the split handle's snap (`DuoSeam.Spring`, the mock's spring) frame
/// by frame on the main actor, so the shell lays the seam out at every step
/// rather than animating between two layouts.
@MainActor
final class V2SeamSpring {
    private var task: Task<Void, Never>?

    var isRunning: Bool { task != nil }

    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Springs from `x` (moving at `velocity`, points per second) to
    /// `target`, handing each step to `step`, then `done` once settled.
    /// Cancelled (a new touch), it stops where it is and `done` never runs.
    func run(from x: Double, velocity: Double, to target: Double, dampingRatio: Double,
             step: @escaping @MainActor (Double) -> Void, done: @escaping @MainActor () -> Void) {
        cancel()
        task = Task { @MainActor [weak self] in
            var spring = DuoSeam.Spring(x: x, velocity: velocity)
            let clock = ContinuousClock()
            let start = clock.now
            var last = start
            while !spring.settled(at: target), clock.now - start < .seconds(2) {
                try? await Task.sleep(for: .milliseconds(8))
                if Task.isCancelled { return }
                let now = clock.now
                spring.step(toward: target, dt: V2SeamSpring.seconds(now - last), dampingRatio: dampingRatio)
                last = now
                step(spring.x)
            }
            if Task.isCancelled { return }
            step(target)
            self?.task = nil
            done()
        }
    }

    private static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) * 1e-18
    }
}
