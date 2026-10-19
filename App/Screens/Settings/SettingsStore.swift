import SwiftUI
import FusionhaKit

// MARK: Store

/// `GET /api/v1/settings`, held once for the whole Settings stack. Every control
/// saves just the key it owns (`PUT /api/v1/settings {key: value}`), optimistically,
/// and rolls back if the server refuses — the web's autosave model.
@MainActor
@Observable
final class SettingsStore {
    private(set) var values: [String: JSONValue] = [:]
    private(set) var loaded = false
    var error: String?
    /// The last failed save, shown as a banner until dismissed.
    var saveError: String?
    let client: APIClient?
    /// The singleton document this store edits: `/api/v1/settings` or, for
    /// File Management, `/api/v1/media-management` (same GET + partial PUT shape).
    let path: String

    init(client: APIClient?, path: String = "/api/v1/settings") {
        self.client = client
        self.path = path
    }

    func load() async {
        guard let client else { return }
        do {
            values = try await client.json("GET", path).object ?? [:]
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    subscript(key: String) -> JSONValue? { values[key] }

    func bool(_ key: String, _ fallback: Bool = false) -> Bool { values[key]?.bool ?? fallback }
    func int(_ key: String, _ fallback: Int = 0) -> Int { values[key]?.int ?? fallback }
    func double(_ key: String, _ fallback: Double = 0) -> Double { values[key]?.double ?? fallback }
    func string(_ key: String, _ fallback: String = "") -> String { values[key]?.string ?? fallback }

    func save(_ key: String, _ value: JSONValue) {
        save([key: value])
    }

    func save(_ diff: [String: JSONValue]) {
        let before = diff.keys.reduce(into: [String: JSONValue]()) { $0[$1] = values[$1] ?? .null }
        for (k, v) in diff { values[k] = v }
        guard let client else { return }
        Task {
            do {
                let fresh = try await client.json("PUT", path, body: .object(diff)).object ?? [:]
                if !fresh.isEmpty { values.merge(fresh) { _, new in new } }
            } catch {
                for (k, v) in before { values[k] = v }
                saveError = "Couldn’t save: \(error.localizedDescription)"
            }
        }
    }

    func boolBinding(_ key: String, _ fallback: Bool = false) -> Binding<Bool> {
        Binding(get: { self.bool(key, fallback) }, set: { self.save(key, .bool($0)) })
    }

    func intBinding(_ key: String, _ fallback: Int = 0) -> Binding<Int> {
        Binding(get: { self.int(key, fallback) }, set: { self.save(key, .number(Double($0))) })
    }

    func stringBinding(_ key: String, _ fallback: String = "") -> Binding<String> {
        Binding(get: { self.string(key, fallback) }, set: { self.save(key, .string($0)) })
    }

    /// The web's `animations_enabled` (General → Enable animations).
    var animationsEnabled: Bool { bool("animations_enabled", true) }
}
