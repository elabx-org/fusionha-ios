import SwiftUI
import UIKit

/// Keeps a field's focus across fold, unfold and rotation. The system ends
/// editing while it moves the window (and its bars) to the new size, so a
/// field that was focused just before the width changed is focused again once
/// the new layout has settled. The width is read without the keyboard, so the
/// keyboard showing or the person dismissing it never counts as a resize.
/// Only the window's own size changing counts: closing the search (its ✕)
/// re-lays the page out at a new width too, and that must not bring the
/// keyboard straight back (build 757 on the open Duo), and neither must a
/// title opening beside Search (the list narrows to a third) while the
/// keyboard changes the window's height (build 781).
private struct FocusAcrossResize: ViewModifier {
    var focused: FocusState<Bool>.Binding
    /// When the field last lost focus.
    @State private var lostAt: Date?
    /// The window's size at the last width change seen.
    @State private var windowSize: CGSize?

    /// A focus loss this close to the resize was the resize's doing.
    private static let window: TimeInterval = 0.8
    /// Long enough for the new layout's bars and keyboard to settle.
    private static let settle: Duration = .milliseconds(350)

    func body(content: Content) -> some View {
        content
            .onChange(of: focused.wrappedValue) { old, new in
                if old && !new { lostAt = .now }
            }
            .onAppear { windowSize = Self.currentWindowSize() }
            .background {
                Color.clear
                    .ignoresSafeArea(.keyboard)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { old, new in
                        guard old > 0, abs(old - new) >= 1 else { return }
                        let now = Self.currentWindowSize()
                        defer { windowSize = now }
                        // The page moved inside the same window, or only the
                        // window's height changed (the open Duo's keyboard):
                        // not a resize. Fold, unfold and rotation change the width.
                        guard let now, let before = windowSize, abs(before.width - now.width) >= 1 else { return }
                        restore()
                    }
            }
    }

    /// The foreground window's size (a fold, unfold or rotation changes it).
    private static func currentWindowSize() -> CGSize? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.keyWindow?.bounds.size
    }

    private func restore() {
        let wasFocused = focused.wrappedValue
            || lostAt.map { Date.now.timeIntervalSince($0) < Self.window } == true
        guard wasFocused else { return }
        Task { @MainActor in
            try? await Task.sleep(for: Self.settle)
            focused.wrappedValue = true
        }
    }
}

extension View {
    /// Re-focuses `focused` after a fold, unfold or rotation if it was focused.
    func keepsFocusAcrossResize(_ focused: FocusState<Bool>.Binding) -> some View {
        modifier(FocusAcrossResize(focused: focused))
    }
}
