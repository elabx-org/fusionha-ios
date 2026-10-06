import Foundation
import WidgetKit
import FusionhaKit

/// Per-widget page state and small caches. The page is kept in the shared
/// keychain and in this process's own UserDefaults, newer copy wins: the dots'
/// intent may run in the app's process rather than the extension's, and on a
/// build signed without the App Group only the keychain is seen by both.
/// Caches stay in the extension's own UserDefaults.
enum WidgetPageStore {
    private struct Stamped<Value: Codable>: Codable {
        let value: Value
        let at: Date
    }

    /// The page-state key for a family: medium and large flick independently.
    static func familyKey(_ family: WidgetFamily) -> String { family == .systemLarge ? "large" : "medium" }

    private static func pageKey(_ family: String) -> String { "widget.Downloads.page.\(family)" }

    static func page(family: String) -> WidgetPage? {
        let key = pageKey(family)
        let shared = decode(Stamped<WidgetPage>.self, SharedKeychain.read(key))
        let local = read(Stamped<WidgetPage>.self, .standard, key)
        return [shared, local].compactMap { $0 }.max { $0.at < $1.at }?.value
    }

    static func setPage(_ page: WidgetPage, family: String) {
        let stamped = Stamped(value: page, at: .now)
        write(stamped, .standard, pageKey(family))
        if let data = try? JSONEncoder().encode(stamped) { SharedKeychain.write(data, pageKey(family)) }
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

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func read<T: Decodable>(_ type: T.Type, _ defaults: UserDefaults, _ key: String) -> T? {
        decode(T.self, defaults.data(forKey: key))
    }

    private static func write<T: Encodable>(_ value: T, _ defaults: UserDefaults, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
