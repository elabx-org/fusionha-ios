import SwiftUI
import UIKit

/// Whether the software keyboard is up, from UIKit's will-show / will-hide
/// notifications. They are posted before the layout pass that moves the page
/// for the keyboard, so a geometry change seen while `shown` is the keyboard's.
@MainActor
final class KeyboardPresence {
    static let shared = KeyboardPresence()
    private(set) var shown = false
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIResponder.keyboardWillShowNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.shown = true }
        })
        observers.append(center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.shown = false }
        })
    }
}

extension FoldInfo {
    /// The shell's geometry with the keyboard left out: while the keyboard is
    /// up, a container that only got shorter (same width) keeps its height.
    /// On the open iPhone Duo the keyboard shortened the measured shell under
    /// the split rule's 500 pt even through `.ignoresSafeArea(.keyboard)`, so
    /// a title opened from Search with the field focused became a sheet; the
    /// sheet took the keyboard away, the height came back, the sheet moved
    /// into the column, the field took focus again and the keyboard shortened
    /// the shell again, round and round (build 781).
    @MainActor
    func steadied(after last: FoldInfo) -> FoldInfo {
        guard KeyboardPresence.shared.shown, last.size.width > 0,
              abs(last.size.width - size.width) < 1, size.height < last.size.height else { return self }
        var steady = self
        steady.size.height = last.size.height
        return steady
    }
}
