import SwiftUI

/// Starts one repeat-forever animation when it appears and hands its 0 → 1
/// flag to the content. Drive a transform or opacity with it: the render loop
/// then interpolates the loop without re-running any view body.
///
/// Use this, never `TimelineView(.animation)`, for a decorative loop (sweeps,
/// shimmers, spinners). A timeline re-evaluates and re-lays out its content
/// every frame, so a screenful of them kept the main thread about half busy
/// on an idle page (Activity's Queue tab first, then the Library grid).
struct RepeatForever<Content: View>: View {
    let animation: Animation
    @ViewBuilder let content: (_ on: Bool) -> Content
    @State private var on = false

    var body: some View {
        content(on)
            .onAppear {
                guard !on else { return }
                withAnimation(animation) { on = true }
            }
    }
}
