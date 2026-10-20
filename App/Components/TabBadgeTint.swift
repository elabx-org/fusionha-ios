import SwiftUI
import UIKit

/// Colours the tab bar's count badges like the web's nav badges (the brand
/// accent with its own text colour, never the system's error red). SwiftUI's
/// `.badge` has no colour, so this reaches the hosting `UITabBarController`
/// and sets each item's `badgeColor`. It re-applies whenever the palette, a
/// count or the shell's size changes, since SwiftUI may rebuild the items, and
/// the system rebuilds the bar when it moves between the horizontal and the
/// vertical axis (fold, unfold, rotation).
struct TabBadgeTint: UIViewControllerRepresentable {
    let fill: UIColor
    let text: UIColor
    /// Anything that changes the badges or the bar (counts, palette, size), so updates re-run.
    let key: String

    /// After the bar's axis change has settled (the size-change transition).
    private static let settleDelay: DispatchTimeInterval = .milliseconds(450)

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        let fill = fill, text = text
        let apply = { [weak vc] in
            guard let root = vc?.view.window?.rootViewController,
                  let tabs = Self.tabBarController(in: root) else { return }
            for item in tabs.tabBar.items ?? [] {
                item.badgeColor = fill
                item.setBadgeTextAttributes([.foregroundColor: text], for: .normal)
                item.setBadgeTextAttributes([.foregroundColor: text], for: .selected)
            }
        }
        DispatchQueue.main.async(execute: apply)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay, execute: apply)
    }

    private static func tabBarController(in vc: UIViewController) -> UITabBarController? {
        if let tabs = vc as? UITabBarController { return tabs }
        for child in vc.children { if let found = tabBarController(in: child) { return found } }
        return vc.presentedViewController.flatMap { tabBarController(in: $0) }
    }
}

extension View {
    /// Tab bar badges in the palette's accent (`TabBadgeTint`).
    func tabBadgeTint(key: String) -> some View {
        background(TabBadgeTint(fill: UIColor(Theme.indigo), text: UIColor(Theme.onAccent),
                                key: key + PaletteStore.shared.active.rawValue)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true))
    }
}
