import Foundation

// MARK: - Fold continuity (v2, owner 2026-11-06)
//
// Folding or unfolding the iPhone Duo is a resize, and v2's screens lay the
// same state out two ways: the open Duo shows a pick on a right page beside
// its list, the folded Duo shows it in a sheet or as a pushed page. These
// are the pure rules that carry the one state between the two layouts; the
// app holds the values (`docs/v2.md`, "Fold continuity").

/// A list's pick: the open Duo's right page (`picked`) or the phone's sheet
/// (`sheet`). They are one selection, so the layout that takes over shows it.
public struct FoldPick<ID: Hashable>: Equatable {
    public var picked: ID?
    public var sheet: ID?

    public init(picked: ID?, sheet: ID?) {
        self.picked = picked
        self.sheet = sheet
    }

    /// After the layout changed to `splits` (true: list and right page).
    /// Unfolding moves an open sheet onto the right page; folding moves the
    /// right page's pick into the sheet and clears the pick, so closing that
    /// sheet folded and unfolding again doesn't bring it back.
    public func reconciled(splits: Bool) -> FoldPick {
        if splits { return FoldPick(picked: sheet ?? picked, sheet: nil) }
        return FoldPick(picked: nil, sheet: sheet ?? picked)
    }
}

/// A split selection and the folded stack of pushed pages that shows it.
public enum FoldRoute {
    /// Folding: the pages to push for the split's pick (none when nothing
    /// is picked). An existing stack wins.
    public static func stack<Page: Hashable>(picked: Page?, stack: [Page]) -> [Page] {
        if !stack.isEmpty { return stack }
        return picked.map { [$0] } ?? []
    }

    /// Unfolding: the deepest pushed page the split can show beside the
    /// list (`shows`), else the pick it already had.
    public static func picked<Page: Hashable>(from stack: [Page], current: Page?,
                                              shows: (Page) -> Bool) -> Page? {
        stack.last(where: shows) ?? current
    }
}

/// The row at a list's top, remembered across a resize. Rows report when
/// they come to the top (`record`); the layout change re-flows the list and
/// reports the new layout's rows in the same moment, so the anchor is the
/// last row that was at the top a little before the resize (`window`).
public struct FoldAnchorLog<ID: Hashable>: Equatable {
    /// Reports this close to the resize belong to the new layout.
    public static var window: TimeInterval { 0.12 }

    public struct Entry: Equatable {
        public let id: ID
        public let time: TimeInterval
    }

    public private(set) var entries: [Entry] = []

    public init() {}

    /// A row came to the list's top at `time`.
    public mutating func record(_ id: ID, at time: TimeInterval) {
        if entries.last?.id == id { return }
        entries.append(Entry(id: id, time: time))
        if entries.count > 8 { entries.removeFirst(entries.count - 8) }
    }

    /// The row that was at the top before a resize at `time`; nil when no
    /// row had settled there (the list was at its top).
    public func anchor(before time: TimeInterval) -> ID? {
        entries.last { $0.time < time - Self.window }?.id
    }

    /// After restoring: the anchor is the newest entry again, so a second
    /// resize (fold, then unfold) finds the same row.
    public mutating func settle(_ id: ID, at time: TimeInterval) {
        entries = [Entry(id: id, time: time)]
    }
}

extension TriageQueueFocus {
    /// The folded deck's order: the queue from the focused request on, then
    /// the ones before it, so the card in front is the one focused open.
    /// With nothing focused it is the queue as it is.
    public func deckOrder(_ order: [Int]) -> [Int] {
        guard let front = effective(order), let at = order.firstIndex(of: front), at > 0 else { return order }
        return Array(order[at...] + order[..<at])
    }
}
