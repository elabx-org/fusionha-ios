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

/// The label of a prominent action whose words carry state ("Approve · 2
/// editions", "Add 3 films", "Rename 4 files"): the icon and the words side by
/// side, like the web's button. A plain `Label` would be cut to its icon by the
/// toolbar (iOS 26 ignores `.labelStyle(.titleAndIcon)` there), losing the
/// count, so this is drawn as its own content. Untested in a vertical bar.
struct ToolbarActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
