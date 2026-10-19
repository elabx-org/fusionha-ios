import Foundation

// MARK: - Open-title continuity across fold, unfold and rotation
//
// The open title is shown by one of two hosts: a sheet (folded, a phone) or
// the shell's trailing column (unfolded, iPad). Moving between them must keep
// the same state: the page (scope, tab, scroll), any child sheet that was up
// (interactive search, Edit, Add version, Rename, Numbering…) and the words
// typed into it. These are the pure rules; the app holds the values.

/// Where the open title's detail is shown.
public enum DetailHost: Equatable, Sendable {
    case sheet, column
}

/// One value kept for the open title (its detail store), so the sheet and the
/// column show the same one. Reused while that title stays open, dropped as
/// soon as it closes or another title opens, so reopening starts fresh.
public struct RetainedSlot<Value> {
    public private(set) var id: Int?
    public private(set) var value: Value?

    public init() {}

    /// The kept value for `id`, or a new one (replacing any other title's).
    public mutating func value(for id: Int, make: () -> Value) -> Value {
        if self.id == id, let value { return value }
        let made = make()
        self.id = id
        value = made
        return made
    }

    /// Keeps the value only while `id` is the open title.
    public mutating func keep(only id: Int?) {
        guard id != self.id else { return }
        self.id = nil
        value = nil
    }
}

/// Which host may open and close the detail's child sheets. While the shell
/// moves the title from one host to the other, the leaving host's sheets are
/// torn down and SwiftUI writes "closed" back through their bindings; those
/// writes must not reach the store, or the arriving host has nothing to
/// re-present. Only the active host's writes count.
public struct DetailHostGate: Equatable, Sendable {
    public private(set) var active: DetailHost = .sheet

    public init() {}

    /// `splitsWithTitle`: the shell would show an open title as a column.
    public mutating func update(splitsWithTitle: Bool) {
        active = splitsWithTitle ? .column : .sheet
    }

    public func accepts(_ host: DetailHost) -> Bool { host == active }
}

/// Words and choices typed into a child sheet, kept while the sheet moves
/// between hosts. Keys are `"<sheet>.<field>"`; opening a sheet afresh clears
/// its own keys so a new presentation never inherits an old draft.
public struct DraftBag {
    private var values: [String: Any] = [:]

    public init() {}

    public var isEmpty: Bool { values.isEmpty }

    public func value<T>(_ key: String, as type: T.Type = T.self) -> T? {
        values[key] as? T
    }

    public mutating func save(_ value: Any, for key: String) {
        values[key] = value
    }

    /// Clears every key of one sheet (`"edit"` clears `"edit.*"`).
    public mutating func clear(sheet: String) {
        let prefix = sheet + "."
        values = values.filter { !$0.key.hasPrefix(prefix) }
    }

    public mutating func removeAll() { values = [:] }

    /// The sheet a key belongs to (`"edit.tags"` → `"edit"`).
    public static func sheet(of key: String) -> String {
        key.split(separator: ".", maxSplits: 1).first.map(String.init) ?? key
    }

    /// Whether a presentation change is a fresh open (so its draft is cleared):
    /// from nothing to something, or from one target to a different one.
    public static func isFreshOpen<ID: Equatable>(from old: ID?, to new: ID?) -> Bool {
        guard let new else { return false }
        return old != new
    }
}
