import SwiftUI

extension EnvironmentValues {
    /// v2's fold continuity (`docs/v2.md`, "Fold continuity"): set by
    /// `V2RootView`, one per window; nil in v1, where nothing changes.
    @Entry var foldKeep: FoldKeep?
}

/// State that has to outlive a view the fold replaces. Folding or
/// unfolding swaps some presentations (a sheet becomes a page cover and
/// back: Add, Manual Import), which builds their content again from
/// scratch; the content keeps its models here, by key, and the
/// presentation drops them once it closes for good.
@MainActor
final class FoldKeep {
    private var objects: [String: AnyObject] = [:]

    /// The kept object for `key`, or a new one.
    func object<T: AnyObject>(_ key: String, make: () -> T) -> T {
        if let kept = objects[key] as? T { return kept }
        let made = make()
        objects[key] = made
        return made
    }

    /// The kept object for `key`, if any.
    func existing<T: AnyObject>(_ key: String, as type: T.Type = T.self) -> T? {
        objects[key] as? T
    }

    func drop(_ key: String) {
        objects[key] = nil
    }

    /// Every key under `prefix` (one presentation's models).
    func drop(prefix: String) {
        for key in objects.keys where key.hasPrefix(prefix) { objects[key] = nil }
    }
}
