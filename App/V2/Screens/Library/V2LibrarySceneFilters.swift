import SwiftUI

/// The v2 Library's filters follow the window (multiple windows, split
/// screen): `V2LibraryView` keeps them in `@SceneStorage`, so two windows
/// side by side can filter differently and each restores its own. A new
/// window starts from the filters used last anywhere, kept under the same
/// `UserDefaults` keys the Library always used (written through below), so
/// a single window behaves as before, relaunch included.
enum V2LibraryFilterSeed {
    static let kindKey = "library.kind"
    static let tierKey = "library.tier"
    static let statusKey = "library.status"
    static let sortKey = "library.sort"
    static let recencyKey = "library.recency"
    static let groupKey = "library.group"
    static let unmonitoredKey = "v2.library.unmonitored"
    static let networkKey = "v2.library.network"

    private static var defaults: UserDefaults { .standard }

    static var kind: String { defaults.string(forKey: kindKey) ?? "all" }
    static var tier: LibraryTier { defaults.string(forKey: tierKey).flatMap(LibraryTier.init(rawValue:)) ?? .all }
    static var status: LibraryStatus {
        defaults.string(forKey: statusKey).flatMap(LibraryStatus.init(rawValue:)) ?? .all
    }
    static var sort: LibrarySort { defaults.string(forKey: sortKey).flatMap(LibrarySort.init(rawValue:)) ?? .title }
    static var recency: LibraryRecency {
        defaults.string(forKey: recencyKey).flatMap(LibraryRecency.init(rawValue:)) ?? .all
    }
    static var group: Bool { defaults.bool(forKey: groupKey) }
    static var unmonitored: Bool { defaults.bool(forKey: unmonitoredKey) }
    static var network: String { defaults.string(forKey: networkKey) ?? "" }
}

/// Writes the window's filters back as the "used last" seed for the next window.
struct V2LibraryFilterWriteThrough: ViewModifier {
    let kind: String
    let tier: LibraryTier
    let status: LibraryStatus
    let sort: LibrarySort
    let recency: LibraryRecency
    let group: Bool
    let unmonitored: Bool
    let network: String

    func body(content: Content) -> some View {
        content
            .onChange(of: kind) { _, value in save(value, V2LibraryFilterSeed.kindKey) }
            .onChange(of: tier) { _, value in save(value.rawValue, V2LibraryFilterSeed.tierKey) }
            .onChange(of: status) { _, value in save(value.rawValue, V2LibraryFilterSeed.statusKey) }
            .onChange(of: sort) { _, value in save(value.rawValue, V2LibraryFilterSeed.sortKey) }
            .onChange(of: recency) { _, value in save(value.rawValue, V2LibraryFilterSeed.recencyKey) }
            .onChange(of: group) { _, value in save(value, V2LibraryFilterSeed.groupKey) }
            .onChange(of: unmonitored) { _, value in save(value, V2LibraryFilterSeed.unmonitoredKey) }
            .onChange(of: network) { _, value in save(value, V2LibraryFilterSeed.networkKey) }
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
