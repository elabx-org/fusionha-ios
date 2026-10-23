import SwiftUI

/// Search rows rise in a short stagger when they land (Duo motion spec): the
/// library's rows first, then each provider's as it answers. A system spring
/// (~0.35 s), no bounce; under Reduce Motion (or animations off) a crossfade.
private struct SearchStagger: ViewModifier {
    let index: Int
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || !motion ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                let delay = Double(min(index, 8)) * 0.04
                withAnimation(motion ? .spring(duration: 0.35, bounce: 0).delay(delay) : .easeInOut(duration: 0.2)) {
                    shown = true
                }
            }
    }
}

extension View {
    /// Rise in on first appearance, `index` places it in the stagger.
    func searchStagger(_ index: Int) -> some View {
        modifier(SearchStagger(index: index))
    }
}

/// The lanes' insert/remove transition: up from below, or a crossfade.
extension AnyTransition {
    static func searchRow(motion: Bool) -> AnyTransition {
        motion ? .opacity.combined(with: .move(edge: .bottom)) : .opacity
    }
}
