import SwiftUI

// MARK: - Select bars hide the downloads bar
//
// The downloads bar is the tab view's bottom accessory, so it floats over the
// bottom of every tab, including a select mode's bulk bar (Library's system
// bottom bar steps the tab bar aside, which leaves the accessory sitting on
// "3 selected"). Every bulk-select bar publishes itself here while on screen,
// and the shell drops the accessory until the last one goes.

/// The bulk-select bars on screen, by bar, published to the shell. Counted,
/// not a set: when a layout swaps one copy of a bar for another (the inbox's
/// list for its wide panes), the new copy can appear before the old one
/// disappears, and a set would then drop a bar that is still showing.
@Observable
final class SelectBarPresence {
    private(set) var counts: [String: Int] = [:]

    /// True while any select mode's bar is showing.
    var isShowing: Bool { !counts.isEmpty }

    func set(_ id: String, shown: Bool) {
        let next = (counts[id] ?? 0) + (shown ? 1 : -1)
        counts[id] = next > 0 ? next : nil
    }
}

extension View {
    /// Tells the shell a bulk-select bar is showing while `active`, so the
    /// downloads bar steps aside instead of covering it.
    func publishesSelectBar(_ id: String, active: Bool = true) -> some View {
        modifier(SelectBarWriter(id: id, active: active))
    }
}

private struct SelectBarWriter: ViewModifier {
    @Environment(SelectBarPresence.self) private var presence: SelectBarPresence?
    @Environment(\.motionEnabled) private var motion
    let id: String
    let active: Bool
    /// Whether this copy of the bar has counted itself in.
    @State private var registered = false

    func body(content: Content) -> some View {
        content
            .onAppear { update(active) }
            .onChange(of: active) { _, shown in update(shown) }
            .onDisappear { update(false) }
    }

    /// The accessory comes and goes with the system's own animation; still
    /// under Reduce Motion.
    private func update(_ shown: Bool) {
        guard let presence, registered != shown else { return }
        registered = shown
        withAnimation(motion ? .smooth(duration: 0.3) : nil) { presence.set(id, shown: shown) }
    }
}
