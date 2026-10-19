import SwiftUI

// The server step's reactions (F2): the same mark that guards the password
// acts out finding the server. Typing the address ticks the pins (`typing`),
// connecting draws sparks in until it answers, reaching it lands a ring and a
// flash, and a refusal jams the pins (`fail`). Plus the media morphs' director.

extension LivingEngine {
    /// While the address is being tried: sparks keep arriving at the blade tips.
    func connecting() {
        guard !reduce, !unlocked else { return }
        connectTask?.cancel()
        listening = false
        setPinsHome()
        connectTask = Task { [weak self] in
            await self?.interrupt(200)
            var k = 0
            while !Task.isCancelled, let self {
                self.launch(k % 3)
                k += 1
                try? await Task.sleep(for: .milliseconds(240 + Int.random(in: 0...160)))
            }
        }
    }

    /// The server answered: a ring from the centre and a flash, then idle again.
    func reached() {
        connectTask?.cancel()
        connectTask = nil
        guard !reduce, !unlocked else { return }
        ring(centre, Self.lilac, size * 0.9)
        animate(mark, 600, [(0, .identity), (0.5, LivingPose(light: 0.5)), (1, .identity)], curve: .easeOut,
                fields: .filter, forwards: false)
        restartIdleSoon()
    }

    /// Nothing (or the wrong thing) answered: the pins jam and the form shakes.
    func refused() {
        connectTask?.cancel()
        connectTask = nil
        fail()
    }

    /// `setMedia`: the server's "Media morphs" toggle, applied as soon as it's known.
    func setMedia(_ on: Bool) {
        guard media != on else { return }
        media = on
    }

    /// Plays one media morph and waits for it (the director then glides home).
    func perform(_ kind: LivingMediaShow.Kind, _ g: Int) async throws {
        posing = true
        mediaShow = LivingMedia.seed(kind, at: clock(), mark: markRect)
        let duration = mediaShow?.duration ?? 0
        defer { if g == gen { mediaShow = nil } }
        try await sleep(duration, g)
    }

    /// The mark's media pose this frame (identity when no media move is on).
    var mediaPose: LivingMediaPose {
        guard let show = mediaShow else { return LivingMediaPose() }
        return LivingMedia.pose(show, ms: (now - show.start) * 1000, size: size)
    }

    private func setPinsHome() {
        settleTask?.cancel()
        setPins(0)
    }
}
