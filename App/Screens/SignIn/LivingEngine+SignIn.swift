import SwiftUI

// The Living mark's sign-in reactions (living/signin.ts): it listens while the
// password has focus, ticks a tumbler pin per key, jams on a wrong password
// and plays the unlock on the right one.

extension LivingEngine {
    /// Password focused: pause the moves and turn toward the form.
    func listen() {
        guard !reduce, !listening, !unlocked else { return }
        listening = true
        restartTask?.cancel()
        Task { await interrupt(260) }
    }

    /// Password blurred: pins home, resume the idle loop soon.
    func unlisten() {
        guard !reduce, !unlocked else { return }
        listening = false
        settleTask?.cancel()
        setPins(0)
        restartIdleSoon()
    }

    /// Password length changed: each key nudges the next blade out of line.
    func typing(_ n: Int) {
        guard !reduce, !unlocked else { return }
        listen()
        setPins(n)
        settleTask?.cancel()
        guard n > 0 else { return }
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Self.settleMs))
            guard !Task.isCancelled else { return }
            self?.setPins(0)
        }
        animate(blades[(n - 1) % 3], 220, [(0, .identity), (0.5, LivingPose(light: 0.35)), (1, .identity)],
                fields: .filter, forwards: false)
    }

    /// A wrong password: the pins jam (an amber shudder), then reset.
    func fail() {
        guard !reduce, !unlocked else { return }
        listening = false
        settleTask?.cancel()
        setPins(0)
        Task {
            await interrupt(200)
            let a: [CGFloat] = [8, -6, 10], b: [CGFloat] = [-5, 4, -6], c: [CGFloat] = [3, -2, 3]
            for (i, blade) in blades.enumerated() {
                animate(blade, 1000, [(0, .identity), (0.18, LivingPose(dx: a[i], scale: 0.94)),
                                      (0.36, LivingPose(dx: b[i], scale: 0.94)), (0.52, LivingPose(dx: c[i], scale: 0.95)),
                                      (1, .identity)],
                        curve: .easeOut, fields: .transform, forwards: false)
                animate(blade, 1000, [(0, .identity), (0.18, LivingPose(light: 0.05, jam: 1)), (1, .identity)],
                        curve: .easeOut, fields: .filter, forwards: false)
            }
        }
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self?.restartIdleSoon()
        }
    }

    /// The right password: the pins line up, a glint, a proud spin, then the
    /// mark dives into the app (~1.24s; sign-in waits `unlockMs`).
    func unlock() {
        guard !reduce, !unlocked else { return }
        unlocked = true
        listening = false
        idleTask?.cancel(); restartTask?.cancel(); settleTask?.cancel()
        setPins(0)
        let wasBusy = busy
        gen += 1
        busy = false
        if wasBusy { Task { await home(160) } }
        sheenStart = clock() + 0.1
        animate(mark, 420, [(0, .identity), (0.5, LivingPose(light: 0.35)), (1, .identity)],
                fields: .filter, delay: 100, forwards: false)
        animate(mark, 620, [(0, .identity), (1, LivingPose(dy: -10, scale: 1.08, rotY: 360))],
                curve: LivingEase.turn, fields: .transform, delay: 380)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }
            self.ring(self.centre, Self.lilac, self.size)
        }
        animate(art, 420, [(0, .identity), (1, LivingPose(scale: 1.35, opacity: 0))], curve: LivingEase.dive, delay: 820)
    }
}
