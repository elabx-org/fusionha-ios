import Foundation
import WidgetKit
import FusionhaKit

/// Per-widget page state and small caches, in the widget extension's own
/// UserDefaults. The App Group may be missing on a re-signed build, so it is
/// only a mirror: the page is written to both and the newer copy wins, which
/// also covers the intent running in the app's process.
enum WidgetPageStore {
    private struct Stamped<Value: Codable>: Codable {
        let value: Value
        let at: Date
    }

    private static let group = UserDefaults(suiteName: "group.org.elabx.fusionha")

    /// The page-state key for a family: medium and large flick independently.
    static func familyKey(_ family: WidgetFamily) -> String { family == .systemLarge ? "large" : "medium" }

    private static func pageKey(_ family: String) -> String { "widget.Downloads.page.\(family)" }

    static func page(family: String) -> WidgetPage? {
        let copies = [UserDefaults.standard, group].compactMap { defaults -> Stamped<WidgetPage>? in
            defaults.flatMap { read(Stamped<WidgetPage>.self, $0, pageKey(family)) }
        }
        return copies.max { $0.at < $1.at }?.value
    }

    static func setPage(_ page: WidgetPage, family: String) {
        let stamped = Stamped(value: page, at: .now)
        for defaults in [UserDefaults.standard, group].compactMap({ $0 }) {
            write(stamped, defaults, pageKey(family))
        }
    }

    /// A cached value no older than `maxAge` seconds (extension defaults only).
    static func cached<Value: Codable>(_ type: Value.Type, _ key: String, maxAge: TimeInterval) -> Value? {
        guard let stamped = read(Stamped<Value>.self, .standard, "widget.cache.\(key)"),
              Date.now.timeIntervalSince(stamped.at) < maxAge else { return nil }
        return stamped.value
    }

    static func cache<Value: Codable>(_ value: Value, _ key: String) {
        write(Stamped(value: value, at: .now), .standard, "widget.cache.\(key)")
    }

    private static func read<T: Decodable>(_ type: T.Type, _ defaults: UserDefaults, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, _ defaults: UserDefaults, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
