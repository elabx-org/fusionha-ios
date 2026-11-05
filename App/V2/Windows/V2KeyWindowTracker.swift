import SwiftUI
import UIKit

/// Tells the session when this window becomes the key window (the person
/// tapped into it), so a notification or widget link opens in the window
/// they used last when two sit side by side. `scenePhase` alone can't say:
/// both windows of a split screen stay active.
struct V2KeyWindowTracker: ViewModifier {
    let model: AppModel

    func body(content: Content) -> some View {
        content.background {
            KeyWindowProbe { [weak model] in
                guard let model else { return }
                model.session.windowBecameActive(model)
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// A zero-size view that watches its own `UIWindow` become key.
private struct KeyWindowProbe: UIViewRepresentable {
    let becameKey: @MainActor () -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.becameKey = becameKey
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.becameKey = becameKey
    }

    static func dismantleUIView(_ view: ProbeView, coordinator: ()) {
        view.stopWatching()
    }

    final class ProbeView: UIView {
        var becameKey: (@MainActor () -> Void)?
        private var observer: NSObjectProtocol?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            stopWatching()
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: UIWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.becameKey?() }
            }
            if window.isKeyWindow { becameKey?() }
        }

        func stopWatching() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
        }
    }
}
