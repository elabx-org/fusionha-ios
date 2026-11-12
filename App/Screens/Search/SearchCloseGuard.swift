import SwiftUI

/// The field's ✕ closes the search for good (owner, builds 1162 and 1165:
/// on the open Duo the keyboard kept coming back). The ✕ ends the search's
/// presentation; the system then re-selects the Search tab and re-activates
/// its field, and other paths (a focus tick, a resize) may ask too. Whatever
/// asks, within a moment of the ✕ the field is put back down. A scroll or a
/// pick only drops focus, so they never start the guard.
struct SearchCloseGuard: ViewModifier {
    var focused: FocusState<Bool>.Binding
    @Binding var presented: Bool
    /// When the ✕ last ended the search.
    @Binding var closedAt: Date?

    /// Long enough to cover the system's echo, short enough that a real tap
    /// on the field a beat later still opens it.
    static let window: TimeInterval = 1

    func body(content: Content) -> some View {
        content
            .onChange(of: presented) { was, now in
                if was && !now {
                    closedAt = .now
                } else if now && Self.justClosed(closedAt) {
                    Task { @MainActor in presented = false }
                }
            }
            .onChange(of: focused.wrappedValue) { was, now in
                guard !was, now, Self.justClosed(closedAt) else { return }
                Task { @MainActor in focused.wrappedValue = false }
            }
    }

    static func justClosed(_ at: Date?) -> Bool {
        at.map { Date.now.timeIntervalSince($0) < window } ?? false
    }
}
