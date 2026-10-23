import Foundation
import FusionhaKit

/// "In your library": the web's `useOmniOwned` over the loaded library, plus
/// any title a provider says you own that the words didn't match (a provider
/// hit you own shows as the library row, never as an add row).
enum OwnedSearch {
    static let cap = 8

    /// Substring match, a trailing 4-digit year filters, prefix matches first,
    /// then newest year first; capped at 8.
    static func matches(_ items: [MediaItem], term: String) -> (rows: [MediaItem], total: Int) {
        let q = term.lowercased()
        guard !q.isEmpty else { return ([], 0) }
        let (title, year) = splitYear(q)
        var scored: [(MediaItem, Int)] = []
        for item in items {
            if let year, let y = item.year, y != year { continue }
            let t = item.title.lowercased()
            guard let range = t.range(of: title) else { continue }
            scored.append((item, range.lowerBound == t.startIndex ? 0 : 1))
        }
        scored.sort { a, b in a.1 != b.1 ? a.1 < b.1 : (a.0.year ?? 0) > (b.0.year ?? 0) }
        return (scored.prefix(cap).map(\.0), scored.count)
    }

    /// The local matches, then the provider-owned titles not already shown.
    static func rows(_ items: [MediaItem], term: String, providerOwned ids: [Int]) -> (rows: [MediaItem], total: Int) {
        let local = matches(items, term: term)
        var all = Set(local.rows.map(\.id))
        var rows = local.rows
        var total = local.total
        for id in ids where !all.contains(id) {
            guard let item = items.first(where: { $0.id == id }) else { continue }
            all.insert(id)
            // Only a title the words missed adds to the count.
            if !Self.matchesWords(item, term: term) { total += 1 }
            if rows.count < cap { rows.append(item) }
        }
        return (rows, total)
    }

    private static func matchesWords(_ item: MediaItem, term: String) -> Bool {
        let (title, year) = splitYear(term.lowercased())
        if let year, let y = item.year, y != year { return false }
        return item.title.lowercased().contains(title)
    }

    private static func splitYear(_ q: String) -> (String, Int?) {
        let pattern = try? NSRegularExpression(pattern: #"^(.*?)[\s(]*\b(\d{4})\)?\s*$"#)
        let ns = q as NSString
        guard let m = pattern?.firstMatch(in: q, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges == 3 else {
            return (q, nil)
        }
        let head = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
        guard !head.isEmpty else { return (q, nil) }
        return (head, Int(ns.substring(with: m.range(at: 2))))
    }
}
