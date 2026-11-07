import SwiftUI

/// Moves a centre-focus carousel to its opening card once it has laid out
/// (owner, 2026-11-07: the row opens centred, with neighbours on both
/// sides). Setting the scroll position before the first layout doesn't
/// hold: the scroll view reports its first card as the centre on appear and
/// overwrites it, so the move waits a beat, once. It goes through the
/// scroll position, as a tap on a side card does, so it lands where a swipe
/// settles (a `ScrollViewReader` centre ignored the content margins and
/// sat the card off centre).
struct V2CarouselOpening: ViewModifier {
    @Binding var opening: Int?
    @Binding var focused: Int?

    func body(content: Content) -> some View {
        content.task(id: opening) {
            guard let id = opening else { return }
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            focused = id
            opening = nil
        }
    }
}

extension View {
    func v2CarouselOpening(_ opening: Binding<Int?>, focused: Binding<Int?>) -> some View {
        modifier(V2CarouselOpening(opening: opening, focused: focused))
    }
}
