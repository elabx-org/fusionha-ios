import Foundation

// MARK: - Fold continuity: places that outlive their host (v2, owner 2026-11-06)
//
// A fold rebuilds the host of a pushed season or episode page (the sheet
// folded, the shell's column open), so what the page scrolled to is kept per
// window and the new host puts it back. The app holds the values
// (`V2TitleStacks`, `V2PagePlace`); these are the rules (`docs/v2.md`,
// "Fold continuity").

/// A scroll offset kept against a header that is laid out differently in the
/// two layouts (the episode page's hero folded, its short header beside the
/// season list open). Inside the header the place is a fraction of it; below
/// it, the distance past its foot, so the content under the eye stays put.
public enum FoldHeaderOffset: Equatable {
    case inHeader(fraction: Double)
    case below(Double)

    /// Where `offset` is on a page whose header is `header` tall.
    public static func place(offset: Double, header: Double) -> FoldHeaderOffset {
        let y = max(0, offset)
        if header > 0, y < header { return .inHeader(fraction: y / header) }
        return .below(y - max(0, header))
    }

    /// The offset that shows the same place under a header `header` tall.
    public func offset(header: Double) -> Double {
        let h = max(0, header)
        switch self {
        case .inHeader(let fraction): return max(0, min(1, fraction)) * h
        case .below(let distance): return h + max(0, distance)
        }
    }
}

/// When a title's stack of pushed pages shrinks, which kept places go: all of
/// them when it is back on the title, else the top layer's (the episodes),
/// so pushing the same page again starts at its top. A fold never changes
/// the stack, so it keeps every place.
public enum FoldPagePlaces {
    public enum Drop: Equatable {
        case none
        /// Every kept place of the title.
        case all
        /// The pages above the stack's new top (the episodes).
        case top
    }

    public static func drop(from old: Int, to new: Int) -> Drop {
        if new >= old { return .none }
        return new == 0 ? .all : .top
    }
}

/// v2's All titles, pushed over Home, one per window (`AppModel.allTitles`).
/// One idempotent path: a tap, a route or a restore `open`s it (once: a
/// second ask while it is pushed, or on its way, pushes nothing); Back, the
/// tab's pop to root or a sign-out `close`s it (and it stays closed). When
/// the shell rebuilds the stack under a kept push (a fold, the launch
/// settling), Home sees it `dropped` and puts the same push back
/// (`withdraw`, then `reassert`) without closing it.
public struct AllTitlesPush: Equatable {
    /// The window shows All titles over Home.
    public private(set) var wanted = false
    /// What the stack's binding reads (false only for a moment while a
    /// dropped push is put back).
    public private(set) var presented = false

    public init() {}

    /// Asks for All titles: true when that is a new push.
    @discardableResult
    public mutating func open() -> Bool {
        guard !wanted else { return false }
        wanted = true
        presented = true
        return true
    }

    /// All titles closed for good.
    public mutating func close() {
        wanted = false
        presented = false
    }

    /// The stack wrote its binding. A pop (false while presented) closes;
    /// a false while a dropped push is being put back is only its echo, and
    /// the stack never pushes on its own.
    /// Returns true when that closed All titles.
    @discardableResult
    public mutating func stackSet(_ shown: Bool) -> Bool {
        guard !shown, presented else { return false }
        close()
        return true
    }

    /// Home is on screen while the push is kept but the page is not: the
    /// stack under it was rebuilt and dropped the page.
    public func dropped(pageOnScreen: Bool) -> Bool {
        wanted && !pageOnScreen
    }

    /// First half of putting a dropped push back: the binding goes false.
    public mutating func withdraw() {
        if wanted { presented = false }
    }

    /// Second half: the binding goes true again (the stack pushes). False
    /// when it was closed meanwhile or is already presented.
    @discardableResult
    public mutating func reassert() -> Bool {
        guard wanted, !presented else { return false }
        presented = true
        return true
    }
}
