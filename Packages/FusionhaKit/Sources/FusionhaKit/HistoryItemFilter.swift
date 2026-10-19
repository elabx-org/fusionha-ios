import Foundation

/// History scoped to one title (web `routes/activity/item-filter.ts`):
/// `?item_id=` is the real filter, `?q=` only the chip's label (never sent as a search).
public struct HistoryItemFilter: Equatable, Sendable {
    public let itemId: Int
    public let label: String

    public init(itemId: Int, label: String) {
        self.itemId = itemId
        self.label = label
    }

    /// From `fusionha://activity/history?item_id=12&q=Dark%20Matter`; nil without a positive id.
    public static func parse(_ url: URL) -> HistoryItemFilter? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let raw = items.first(where: { $0.name == "item_id" })?.value, let id = Int(raw), id > 0 else { return nil }
        let q = items.first(where: { $0.name == "q" })?.value ?? ""
        return HistoryItemFilter(itemId: id, label: q.isEmpty ? "this title" : q)
    }
}
