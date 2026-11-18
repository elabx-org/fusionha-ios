import UIKit

/// Covers a whole-shell change with the window as it looked just before, so
/// the change itself never shows half done (owner-approved mock "Title Motion
/// Options", 2026-11-18). The cover is a snapshot view animated by Core
/// Animation, so it stays smooth however long the change takes to lay out,
/// and the live views under it keep their state (scroll positions, focus).
@MainActor
enum ShellCover {
    /// The Library re-flowing after a title lands: the old grid fades out over
    /// the new one.
    static func crossfade(duration: Double = 0.2, motion: Bool, _ change: () -> Void) {
        guard motion, let window = keyWindow, let snapshot = window.snapshotView(afterScreenUpdates: false) else {
            return change()
        }
        snapshot.isUserInteractionEnabled = false
        window.addSubview(snapshot)
        change()
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            snapshot.alpha = 0
        } completion: { _ in snapshot.removeFromSuperview() }
    }

    /// Split to full width and back (one column becomes the band over two):
    /// the old layout blurs out, the new one is swapped in at the peak and
    /// comes back sharp, never both at once.
    static func blurThrough(duration: Double = 0.3, motion: Bool, _ change: () -> Void) {
        guard motion, let window = keyWindow, let snapshot = window.snapshotView(afterScreenUpdates: false) else {
            return change()
        }
        let blur = UIVisualEffectView(effect: nil)
        blur.frame = window.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        for view in [snapshot, blur] as [UIView] {
            view.isUserInteractionEnabled = false
            window.addSubview(view)
        }
        change()
        let half = duration / 2
        UIView.animate(withDuration: half, delay: 0, options: [.curveEaseIn]) {
            blur.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        } completion: { _ in
            snapshot.removeFromSuperview()
            UIView.animate(withDuration: half, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                blur.effect = nil
            } completion: { _ in blur.removeFromSuperview() }
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
