import SwiftUI

/// What a v2 window opened with "Open in New Window" shows: one title. The
/// app's `WindowGroup(for:)` takes it (nil for an ordinary window), and
/// SwiftUI keeps it with the scene, so a restored window knows its title.
struct V2TitleWindow: Codable, Hashable {
    let itemId: Int
}

/// "Open in New Window" for a title (the poster's long-press menus and the
/// title page's More menu). Hidden where the system offers one window only.
struct OpenInNewWindowButton: View {
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow
    let itemId: Int

    var body: some View {
        if supportsMultipleWindows {
            Button(Self.label, systemImage: Self.symbol) {
                openWindow(value: V2TitleWindow(itemId: itemId))
            }
        }
    }

    static let label = "Open in New Window"
    static let symbol = "macwindow.badge.plus"
}

/// The poster sheet's row for the same action, in the sheet's own row style.
struct OpenInNewWindowSheetRow: View {
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow
    let index: Int
    let itemId: Int
    let dismiss: () -> Void

    var body: some View {
        if supportsMultipleWindows {
            SheetSeparator()
            SheetRow(index: index, label: OpenInNewWindowButton.label, icon: OpenInNewWindowButton.symbol) {
                dismiss()
                openWindow(value: V2TitleWindow(itemId: itemId))
            }
        }
    }
}
