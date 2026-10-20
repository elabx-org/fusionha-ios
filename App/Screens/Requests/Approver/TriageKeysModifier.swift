import SwiftUI
import UIKit
import FusionhaKit

extension EnvironmentValues {
    /// The Inbox owns the keyboard: false while one of its own sheets, the
    /// thread panel, the drawer or the filter is open (web `keysEnabled`).
    @Entry var triageKeysEnabled = false
}

extension View {
    /// A / D / J / K / Return / X on a hardware keyboard (web `useTriageKeys`).
    /// `perform` returns false when the key did nothing, so it passes on.
    func triageKeys(on surface: TriageKeys.Surface, perform: @escaping (TriageKeys.Action) -> Bool) -> some View {
        modifier(TriageKeysModifier(surface: surface, perform: perform))
    }
}

/// The view takes keyboard focus and handles the triage keys only while it
/// holds that focus itself (so never while a text field or a focused button
/// has it), the Inbox has the keys, nothing is typing, and no sheet, dialog,
/// popover or menu sits above the one it appeared under.
struct TriageKeysModifier: ViewModifier {
    let surface: TriageKeys.Surface
    let perform: (TriageKeys.Action) -> Bool
    @Environment(\.triageKeysEnabled) private var enabled
    @FocusState private var focused: Bool
    /// The presentations already up when this view appeared (a sheet's own).
    @State private var baseline = 0

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress(phases: .down) { press in
                MainActor.assumeIsolated { handle(press) }
            }
            .onAppear {
                baseline = KeyboardContext.presentationDepth()
                if enabled { focused = true }
            }
            // Focus comes back when whatever covered the Inbox closes.
            .onChange(of: enabled) { _, on in if on { focused = true } }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        let mods = press.modifiers
        guard let action = TriageKeys.action(characters: press.characters, isReturn: press.key == .return,
                                             command: mods.contains(.command), control: mods.contains(.control),
                                             option: mods.contains(.option), isRepeat: press.phase == .repeat),
              TriageKeys.accepts(action, on: surface),
              TriageKeys.allowed(enabled: enabled && focused, typing: KeyboardContext.isTyping,
                                 overlayOpen: KeyboardContext.overlayOpen(above: baseline))
        else { return .ignored }
        return perform(action) ? .handled : .ignored
    }
}

/// What UIKit knows that SwiftUI doesn't say: the first responder and the
/// presentations over the key window.
@MainActor
enum KeyboardContext {
    fileprivate static weak var captured: UIResponder?

    /// A text field or text view is the first responder.
    static var isTyping: Bool {
        captured = nil
        UIApplication.shared.sendAction(#selector(UIResponder.fusionhaCaptureFirstResponder), to: nil, from: nil, for: nil)
        return captured is UITextField || captured is UITextView
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)
    }

    /// Sheets, popovers, alerts and confirmation dialogs stacked on the root.
    static func presentationDepth() -> Int {
        var controller = keyWindow?.rootViewController
        var depth = 0
        while let next = controller?.presentedViewController {
            depth += 1
            controller = next
        }
        return depth
    }

    /// A menu (a `Menu` or a context menu) is up: UIKit hosts it in a
    /// container view on the window rather than presenting a controller.
    static var menuOpen: Bool {
        keyWindow?.subviews.contains { String(describing: type(of: $0)).contains("ContextMenu") } ?? false
    }

    static func overlayOpen(above baseline: Int) -> Bool {
        presentationDepth() > baseline || menuOpen
    }
}

extension UIResponder {
    @objc func fusionhaCaptureFirstResponder() {
        KeyboardContext.captured = self
    }
}
