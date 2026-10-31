import SwiftUI

// A hardware keyboard's Escape closes the frontmost sheet, as its Close /
// Cancel button would (iPad, Magic Keyboard). One `.cancelAction` per visible
// hierarchy: a nested sheet's wins as the frontmost, but two in the same
// presentation would fight, so a host that takes Escape itself (the Duo page
// cover, through its close guard) switches its content's off.

extension EnvironmentValues {
    /// True inside a Duo page cover: the cover's own Escape closes it.
    @Entry var escapeTakenByHost = false
}

extension View {
    /// Escape presses this button, unless `enabled` is false or a host above
    /// already takes it.
    func closeOnEscape(_ enabled: Bool = true) -> some View {
        modifier(CloseOnEscape(enabled: enabled))
    }
}

private struct CloseOnEscape: ViewModifier {
    @Environment(\.escapeTakenByHost) private var taken
    let enabled: Bool

    func body(content: Content) -> some View {
        content.keyboardShortcut(enabled && !taken ? KeyboardShortcut.cancelAction : nil)
    }
}
