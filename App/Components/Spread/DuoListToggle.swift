import SwiftUI
import FusionhaKit

// MARK: - The sidebar button (option A, owner 2026-10-24)
//
// Flat open, a system `sidebar.left` button in the detail's bar (the column)
// hides or shows the list beside it, so the detail fills the inner display.
// Remembered per tab (`DuoListMemory`, one per-device string). In book pose
// the list never hides (a detail across the display would run over the fold),
// so the button isn't offered there. Spread and the Web layout alike.

/// The shell's hide / show action, handed to the detail column. `nil` when
/// the list can't hide here (folded, book pose, nothing beside the list).
struct DuoListToggle {
    var hidden: Bool
    var toggle: @MainActor () -> Void
}

extension EnvironmentValues {
    @Entry var duoListToggle: DuoListToggle? = nil
}

extension AppTab {
    /// The tab's key in `DuoListMemory`.
    var listMemoryKey: String { String(describing: self) }
}

extension View {
    /// The sidebar button in this page's bar, while the shell offers it.
    func duoListToggleToolbar() -> some View {
        modifier(DuoListToggleToolbar())
    }
}

private struct DuoListToggleToolbar: ViewModifier {
    @Environment(\.duoListToggle) private var toggle

    func body(content: Content) -> some View {
        content.toolbar {
            if let toggle {
                ToolbarItem(placement: .topBarLeading) {
                    Button(toggle.hidden ? "Show list" : "Hide list", systemImage: "sidebar.left") {
                        toggle.toggle()
                    }
                    .accessibilityHint(toggle.hidden ? "Shows the list beside this page"
                                                     : "Gives this page the whole display")
                }
                .barPriority(true)
            }
        }
    }
}
