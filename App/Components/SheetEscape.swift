import SwiftUI

// A hardware keyboard's Escape closes the frontmost sheet, as its Close /
// Cancel button would (iPad, Magic Keyboard). One `.cancelAction` per visible
// hierarchy: a nested sheet's wins as the frontmost, but two in the same
// presentation would fight, so a host that takes Escape itself (the Duo page
// cover, through its close guard) switches its content's off.
//
// That switch is an environment value, and environment values flow into every
// presentation opened from inside the cover. A plain `.sheet` / cover opened
// anywhere under a Duo page must apply `sheetEscapeRoot()` to its content, or
// its Close stays dead (`duoPageSheet` does it for its own sheets).

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

    /// The root of a sheet's content: Escape belongs to this presentation
    /// again, even when it was opened from inside a Duo page cover, and its
    /// `sheetBackground` is drawn again (it is a sheet, not a page).
    func sheetEscapeRoot() -> some View {
        environment(\.escapeTakenByHost, false)
            .environment(\.onDuoPage, false)
    }
}

private struct CloseOnEscape: ViewModifier {
    @Environment(\.escapeTakenByHost) private var taken
    let enabled: Bool

    func body(content: Content) -> some View {
        content.keyboardShortcut(enabled && !taken ? KeyboardShortcut.cancelAction : nil)
    }
}
