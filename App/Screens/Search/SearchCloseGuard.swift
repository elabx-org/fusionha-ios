import SwiftUI
import UIKit

/// The field's ✕ closes the search for good (owner, builds 1162, 1165 and
/// 1171: on the open Duo the keyboard kept coming back). Builds 1165 and 1167
/// watched SwiftUI's focus and presentation, but the Search tab's field
/// (a `.search` role tab) can be re-activated by the system without either
/// binding changing. So this watches the field itself: once the Search
/// field stops editing, it starting again within a moment is put straight
/// back down, whatever asked. A tap on the field a
/// beat later still opens it. Fields in sheets are never touched.
struct SearchCloseGuard: ViewModifier {
    var focused: FocusState<Bool>.Binding
    @Binding var presented: Bool
    /// When the Search field last stopped editing.
    @Binding var closedAt: Date?
    /// The Search tab is the one on screen.
    var active: Bool

    /// Long enough to cover the system's echo, short enough that a real tap
    /// on the field a beat later still opens it.
    static let window: TimeInterval = 1

    func body(content: Content) -> some View {
        content
            .onChange(of: presented) { was, now in
                if was && !now { closedAt = .now }
            }
            // The field's own editing events: they come whatever asked (SwiftUI,
            // the tab, the system) and on every keyboard, split and floating
            // ones included, which send no keyboard show / hide notifications.
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { note in
                if active, note.object is UISearchTextField { closedAt = .now }
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
                guard active, note.object is UISearchTextField, Self.justClosed(closedAt) else { return }
                putDown()
            }
            .onChange(of: focused.wrappedValue) { was, now in
                guard !was, now, active, Self.justClosed(closedAt) else { return }
                putDown()
            }
    }

    private func putDown() {
        Task { @MainActor in
            focused.wrappedValue = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            // Each put-down restarts the window, so a repeated echo stays down.
            closedAt = .now
        }
    }

    static func justClosed(_ at: Date?) -> Bool {
        at.map { Date.now.timeIntervalSince($0) < window } ?? false
    }
}
