import SwiftUI

/// The scroll thumb's track: the thumb at the page's progress and the letter
/// bubble beside it. A view of its own, so a scroll that moves the thumb
/// re-renders only this, never the `ScrollScrubber` reader around it.
struct ScrubberTrack: View {
    let state: ScrubberState
    let letters: [String]
    let height: CGFloat
    let jump: (String) -> Void

    @Environment(\.motionEnabled) private var motion
    @State private var touchStart: CGFloat?
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        let _ = PerfCount.hit("ScrubberTrack.body")
        let y = state.progress * (height - ScrubberState.thumbHeight)
        ZStack(alignment: .topTrailing) {
            ScrubberBubble(letter: state.bubble, tick: state.tick)
                .offset(x: -48, y: y - 4)
            thumb
                .offset(y: y)
        }
        .frame(width: 110, height: height, alignment: .topTrailing)
    }

    private var thumb: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 24, style: .continuous)
        let grabbed = state.bubble != nil
        return ThumbArrows()
            .fill(.white)
            .frame(width: 12, height: 22)
            .frame(width: 34, height: ScrubberState.thumbHeight)
            // A control, so glass: tinted with the web's `--mut` 72% (92% while grabbed).
            .glassEffect(.regular.tint(Theme.mut.opacity(grabbed ? 0.92 : 0.72)).interactive(), in: shape)
            .shadow(color: .black.opacity(0.35), radius: 7, y: 4)
            .contentShape(shape)
            .opacity(state.visible ? 1 : 0)
            .offset(x: state.visible ? 0 : 14)
            .animation(motion ? .easeOut(duration: 0.22) : nil, value: state.visible)
            .animation(motion ? .easeOut(duration: 0.12) : nil, value: grabbed)
            .allowsHitTesting(state.visible)
            .gesture(drag)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(ScrollScrubber.space))
            .onChanged { value in
                let y = value.location.y
                guard let start = touchStart else {
                    touchStart = y
                    holdTask?.cancel()
                    holdTask = Task {
                        try? await Task.sleep(for: ScrubberState.holdTime)
                        guard !Task.isCancelled else { return }
                        state.engage(at: y, height: height, letters: letters)
                    }
                    return
                }
                if !state.scrubbing {
                    guard abs(y - start) >= ScrubberState.engageDistance else { return }
                    holdTask?.cancel()
                    state.engage(at: start, height: height, letters: letters)
                }
                state.scrub(to: y, height: height, letters: letters, jump: jump)
            }
            .onEnded { _ in
                holdTask?.cancel()
                holdTask = nil
                touchStart = nil
                state.end(jump: jump)
            }
    }
}

/// The thumb's up/down chevron pair (`M6 1 11 8H1zM6 21 1 14h10z` in a 12×22 box).
private struct ThumbArrows: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 12, sy = rect.height / 22
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(6, 1)); path.addLine(to: p(11, 8)); path.addLine(to: p(1, 8)); path.closeSubpath()
        path.move(to: p(6, 21)); path.addLine(to: p(1, 14)); path.addLine(to: p(11, 14)); path.closeSubpath()
        return path
    }
}
