import Foundation

/// The Search tab's recent searches (before you type): the last 5 terms, most
/// recent first, kept on this device only.
public struct RecentSearches: Equatable, Sendable {
    public static let limit = 5
    public private(set) var terms: [String]

    public init(terms: [String] = []) {
        self.terms = Array(terms.prefix(Self.limit))
    }

    /// Puts `term` first; the same words in another case replace the older one.
    public mutating func record(_ raw: String) {
        let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        terms.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        terms.insert(term, at: 0)
        if terms.count > Self.limit { terms.removeLast(terms.count - Self.limit) }
    }

    public mutating func remove(_ term: String) {
        terms.removeAll { $0 == term }
    }

    // MARK: Storage

    public static let defaultsKey = "unifiedSearch.recent"

    public static func load(from defaults: UserDefaults, key: String = defaultsKey) -> RecentSearches {
        RecentSearches(terms: defaults.stringArray(forKey: key) ?? [])
    }

    public func save(to defaults: UserDefaults, key: String = defaultsKey) {
        defaults.set(terms, forKey: key)
    }
}
