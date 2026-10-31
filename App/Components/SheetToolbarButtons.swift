import SwiftUI

// Toolbar buttons for sheets and the title column.
//
// Every toolbar item carries a title AND an icon. The system then picks: the
// icon in a horizontal bar and in the vertical bar that iPhone Duo (iOS 27.1
// SDK) uses on its outer display and in landscape, both in the overflow menu.
// An item with a title and no icon is never moved into a vertical bar, and an
// icon-only item has no title for the overflow menu. The title is also the
// VoiceOver label.

/// Cancel / Close: an ✕, placed first (`.cancellationAction`). Escape
/// presses it (`closeOnEscape`); `escapeCloses: false` where it isn't a
/// sheet's (the detail as the shell's column).
struct SheetCancelButton: View {
    var title = "Cancel"
    var escapeCloses = true
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: "xmark", role: .cancel, action: action)
            .closeOnEscape(escapeCloses)
    }
}

/// Done / Save: a ✓ (`.confirmationAction`). `escapeCloses: true` only when
/// it is the sheet's sole way out and just closes: Escape never saves.
struct SheetDoneButton: View {
    var title = "Done"
    var escapeCloses = false
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: "checkmark", action: action)
            .closeOnEscape(escapeCloses)
    }
}

/// A sheet's prominent action whose words carry state ("Approve · 2
/// editions", "Add 3 films", "Rename 4 files"): a plain system item, title AND
/// icon, so it joins the iPhone Duo's vertical bar with the rest (a custom
/// label view stays horizontal and splits the bar). The bar shows the icon,
/// the overflow menu and VoiceOver the words.
///
/// While `busy` it stays the same item, disabled, its icon pulsing (steady
/// under Reduce Motion), so the bar never swaps it for a spinner and jumps.
struct ToolbarActionButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    var busy: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(title: String, systemImage: String, role: ButtonRole? = nil, busy: Bool = false,
         action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.busy = busy
        self.action = action
    }

    var body: some View {
        Button(title, systemImage: systemImage, role: role, action: action)
            .symbolEffect(.pulse, options: .repeating, isActive: busy && !reduceMotion)
            .disabled(busy)
            .accessibilityValue(busy ? "In progress" : "")
    }
}
