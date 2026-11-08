import SwiftUI

/// Moves a centre-focus carousel to its opening card once it has laid out
/// (owner, 2026-11-07: the row opens centred, with neighbours on both
/// sides), and keeps it there until the owner touches the row. A single
/// move after a beat didn't hold: when the page around it laid out again
/// (the screen-centre skew arriving, a Needs you card loading above) the
/// carousel's width and margins changed and the scroll view snapped back to
/// its first card, which then became the remembered card (owner, IMG_7890).
/// It goes through the scroll position, as a tap on a side card does, so it
/// lands where a swipe settles.
struct V2CarouselOpening: ViewModifier {
    @Binding var opening: Int?
    @Binding var focused: Int?
    /// The card being held until the owner scrolls or the page settles.
    @State private var held: Int?

    /// How long the opening card is held against layout passes.
    private static let hold: Duration = .seconds(2.5)

    func body(content: Content) -> some View {
        content
            .task(id: opening) {
                guard let id = opening else { return }
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                held = id
                focused = id
                opening = nil
                try? await Task.sleep(for: Self.hold)
                if held == id { held = nil }
            }
            .onScrollPhaseChange { _, phase in
                // A swipe, or a tap on a side card (which animates), is the owner's move.
                if phase == .interacting || phase == .animating { held = nil }
            }
            .onChange(of: focused) { _, now in
                guard let held, now != held else { return }
                // A relayout moved it, not the owner: put it back.
                Task { @MainActor in if self.held == held { focused = held } }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _ in
                guard let held else { return }
                Task { @MainActor in if self.held == held { focused = held } }
            }
    }
}

extension View {
    func v2CarouselOpening(_ opening: Binding<Int?>, focused: Binding<Int?>) -> some View {
        modifier(V2CarouselOpening(opening: opening, focused: focused))
    }
}
