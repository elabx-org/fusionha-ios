import SwiftUI
import FusionhaKit

// MARK: - The split handle (owner-approved 2026-11-05)
//
// Mock: https://claude.ai/artifact/8FMR9KrECRveDDvqn3xUBi. On the flat open
// Duo's seamless split (list a third | title) a glass pill sits on the seam.
// Drag it and the seam follows the finger (`DuoSeamDrag.live`, laid out by
// `FoldSeam`); let go and it snaps to full width, the split or closed
// (`DuoSeam`), with a light tick at each stop and on crossing into another
// stop's zone. Tap it to switch split and full width. The first time, it
// nudges twice beside a tip, until it has been touched once.

struct V2SplitHandle: View {
    let context: DuoSeamContext
    @Environment(\.motionEnabled) private var motion
    @Environment(AppModel.self) private var model
    /// Set once the handle has been touched: the tip never shows again.
    @AppStorage("v2.splitHandle.used") private var used = false
    /// Where the seam was when the finger went down, and whether it has moved.
    @State private var start: (x: Double, moved: Bool)?
    @State private var zone: DuoSeam.Stop = .split
    @State private var ticks = 0
    @State private var spring = V2SeamSpring()
    @State private var tipShown = false
    @State private var nudge: CGFloat = 0
    @GestureState private var gripTouched = false
    @GestureState private var stripTouched = false

    private var seam: DuoSeamDrag { context.drag }
    private var width: Double { Double(context.width) }
    private var rest: Double { Double(context.rest) }
    private var restingStop: DuoSeam.Stop { context.fullWidth ? .fullWidth : .split }
    /// The seam now: under the finger or the spring, else at its stop.
    private var x: Double {
        seam.live.map { Double($0) } ?? DuoSeam.position(of: restingStop, width: width, split: rest)
    }
    private var held: Bool { start != nil }
    /// The pill stays whole on screen at either end.
    private var gripX: CGFloat { CGFloat(min(max(x, 6), width - 6)) }

    var body: some View {
        ZStack(alignment: .leading) {
            if seam.live != nil, !seam.listFull { V2SeamGround(context: context, x: CGFloat(x)) }
            if seam.live != nil, motion {
                Color.black.opacity(DuoSeam.listShade(x: x, split: rest))
                    .frame(width: CGFloat(max(0, x)))
                    .frame(maxHeight: .infinity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            labels
            strip
            grip
            V2SplitTip()
                .padding(.leading, gripX + 23)
                .opacity(tipShown ? 1 : 0)
        }
        // The shell's own frame (its columns are placed from its leading
        // edge, inside the safe area), so the pill sits on the seam.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .sensoryFeedback(.impact(weight: .light), trigger: ticks)
        .onChange(of: gripTouched || stripTouched) { _, touching in
            // A touch the system cancelled never ends its drag: settle it here.
            guard !touching else { return }
            Task { @MainActor in if start != nil { release(velocity: 0) } }
        }
        .task { await firstTimeHint() }
        .onAppear {
            seam.handleShown = true
            slideIn()
        }
        .onChange(of: seam.closeRequests) { slideOut() }
        .onDisappear {
            spring.cancel()
            seam.handleShown = false
            seam.live = nil
            seam.listFull = false
            if model.presentedItem == nil { seam.slidIn = nil }
        }
    }

    // MARK: Pieces

    private var labels: some View {
        ZStack(alignment: .leading) {
            V2SplitLabel(title: "Full width")
                .padding(.leading, 15)
                .opacity(held ? DuoSeam.fullLabel(x: x, split: rest) : 0)
            V2SplitLabel(title: "Close", systemImage: "xmark")
                .frame(width: CGFloat(max(0, x - 19)), alignment: .trailing)
                .opacity(held ? DuoSeam.closeLabel(x: x, split: rest) : 0)
        }
    }

    /// The seam's whole height (under the bar, so its buttons stay tappable),
    /// as the edge strip was: a drag here moves the seam too.
    private var strip: some View {
        Color.clear
            .frame(width: CGFloat(DuoSwipe.edgeWidth))
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .padding(.top, 64)
            .offset(x: gripX - CGFloat(DuoSwipe.edgeWidth) / 2)
            .gesture(seamDrag(minimumDistance: 10).updating($stripTouched) { _, state, _ in state = true })
            .accessibilityHidden(true)
    }

    private var grip: some View {
        V2SplitGrip(held: held, motion: motion)
            .offset(x: nudge)
            .frame(width: 44, height: 120)
            .contentShape(Rectangle())
            .offset(x: gripX - 22)
            .opacity(x >= width ? 0 : 1)
            .gesture(seamDrag(minimumDistance: 0).updating($gripTouched) { _, state, _ in state = true })
            .accessibilityElement()
            .accessibilityLabel("Split between the list and the title")
            .accessibilityValue(context.fullWidth ? "Full width" : "Split")
            .accessibilityHint("Drag to resize, or drag right to close")
            .accessibilityAction { settle(DuoSeam.tapTarget(x: x, split: rest), velocity: 0) }
            .accessibilityAction(named: "Full width") { settle(.fullWidth, velocity: 0) }
            .accessibilityAction(named: "Split") { settle(.split, velocity: 0) }
            .accessibilityAction(named: "Close") { settle(.closed, velocity: 0) }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: settle(DuoSeam.next(from: restingStop, towardClose: true), velocity: 0)
                case .decrement: settle(DuoSeam.next(from: restingStop, towardClose: false), velocity: 0)
                @unknown default: break
                }
            }
    }

    // MARK: Dragging

    private func seamDrag(minimumDistance: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: minimumDistance, coordinateSpace: .global)
            .onChanged { value in follow(value.translation.width) }
            .onEnded { value in release(velocity: Double(value.velocity.width)) }
    }

    private func follow(_ dx: CGFloat) {
        var touch = start ?? begin()
        if abs(dx) > CGFloat(DuoSeam.tapSlop) { touch.moved = true }
        start = touch
        let next = DuoSeam.rubberBand(touch.x + Double(dx), width: width)
        seam.live = CGFloat(next)
        let now = DuoSeam.zone(next, width: width, split: rest)
        if now != zone {
            zone = now
            ticks += 1
        }
    }

    /// The finger went down: catch the seam where it is (even mid-snap).
    private func begin() -> (x: Double, moved: Bool) {
        spring.cancel()
        hideHint()
        let from = x
        zone = DuoSeam.zone(from, width: width, split: rest)
        return (from, false)
    }

    private func release(velocity: Double) {
        guard let touch = start else { return }
        start = nil
        guard touch.moved else {
            settle(DuoSeam.tapTarget(x: touch.x, split: rest), velocity: 0)
            return
        }
        settle(DuoSeam.target(x: x, velocity: velocity, width: width, split: rest), velocity: velocity)
    }

    /// Spring to `stop`, then hand it to the shell.
    private func settle(_ stop: DuoSeam.Stop, velocity: Double, tick: Bool = true) {
        if tick { ticks += 1 }
        let from = x
        let target = DuoSeam.position(of: stop, width: width, split: rest)
        let drag = context.drag
        let shell = context
        spring.run(from: from, velocity: velocity, to: target,
                   dampingRatio: motion ? DuoSeam.dampingRatio : 1,
                   step: { drag.live = CGFloat($0) },
                   done: { Self.commit(stop, context: shell) })
    }

    /// The seam is at `stop`: the shell takes over at rest, in one frame.
    private static func commit(_ stop: DuoSeam.Stop, context: DuoSeamContext) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            switch stop {
            case .fullWidth: context.setFullWidth(true)
            case .split: context.setFullWidth(false)
            case .closed: context.close()
            }
            context.drag.live = nil
            context.drag.listFull = false
        }
    }

    /// A title just opened: it slides in from the trailing edge to its stop
    /// (the split, or the full width when the list is hidden), the close
    /// drag played backwards, over the Library at its full width
    /// (`FoldSeam`). Once per title opened, not when the handle comes back
    /// for one already open.
    private func slideIn() {
        let id = model.presentedItem?.id
        guard seam.slidIn != id else { return }
        seam.slidIn = id
        guard motion, seam.live == nil else { return }
        seam.listFull = true
        seam.live = CGFloat(width)
        settle(restingStop, velocity: 0, tick: false)
    }

    /// Close: the title slides off the trailing edge over the Library at its
    /// full width, then closes (at once under Reduce Motion).
    private func slideOut() {
        guard motion else {
            context.close()
            return
        }
        spring.cancel()
        start = nil
        if seam.live == nil { seam.live = CGFloat(x) }
        seam.listFull = true
        settle(.closed, velocity: 0, tick: false)
    }

    // MARK: First time

    private func hideHint() {
        used = true
        tipShown = false
        nudge = 0
    }

    /// Shown until the handle is first touched: the tip for about four
    /// seconds, and two nudges (none under Reduce Motion).
    private func firstTimeHint() async {
        guard !used else { return }
        try? await Task.sleep(for: .milliseconds(900))
        guard !used, !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.35)) { tipShown = true }
        let clock = ContinuousClock()
        let shownAt = clock.now
        if motion {
            for _ in 0..<2 where !used {
                await nudgeOnce()
            }
        }
        try? await Task.sleep(until: shownAt + .milliseconds(4200), clock: clock)
        guard !used else { return }
        withAnimation(.easeOut(duration: 0.35)) { tipShown = false }
    }

    /// One nudge (the mock's 1.1s keyframes: left, right, home).
    private func nudgeOnce() async {
        let steps: [(CGFloat, Double)] = [(-15, 0.33), (11, 0.33), (0, 0.44)]
        for (offset, duration) in steps {
            guard !used, !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: duration)) { nudge = offset }
            try? await Task.sleep(for: .seconds(duration))
        }
    }
}
