import SwiftUI

// Toolbar buttons for sheets and the title column.
//
// Every toolbar item carries a title AND an icon. The system then picks: the
// icon in a horizontal bar and in the vertical bar that iPhone Duo (iOS 27.1
// SDK) uses on its outer display and in landscape, both in the overflow menu.
// An item with a title and no icon is never moved into a vertical bar, and an
// icon-only item has no title for the overflow menu. The title is also the
// VoiceOver label.

/// Cancel / Close: an ✕, placed first (`.cancellationAction`).
struct SheetCancelButton: View {
    var title = "Cancel"
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: "xmark", role: .cancel, action: action)
    }
}

/// Done / Save: a ✓ (`.confirmationAction`).
struct SheetDoneButton: View {
    var title = "Done"
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: "checkmark", action: action)
    }
}

/// The label of a prominent action whose words carry state ("Approve · 2
/// editions", "Add 3 films", "Rename 4 files"): in a horizontal bar the words
/// stay visible beside the icon, like the web's button.
struct ToolbarActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
    }
}
