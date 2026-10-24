import Foundation

/// The open iPhone Duo's posture, read from the system's reserved `.division`
/// region (`reservedRegions(kind: .division)`): an active region means the
/// device is partially folded (book) and the fold is reserved; with only an
/// inactive, zero-wide one (`options: .includeInactive`) the device lies flat
/// and the inner display is one surface (HIG, "Designing for iPhone Duo").
/// Never inferred from the width.
public enum DuoPosture: Sendable, Equatable {
    case flat
    case book

    /// `activeDivision`: the active (non-`includeInactive`) `.division`
    /// regions run top to bottom through the container.
    public init(activeDivision: Bool) {
        self = activeDivision ? .book : .flat
    }

    /// Book pose reserves the fold: nothing interactive on it, equal pages.
    public var reservesFold: Bool { self == .book }

    /// Only flat can hide the list: in book pose a detail across the whole
    /// display would run over the fold.
    public var canHideList: Bool { self == .flat }
}

/// Option A (owner-approved 2026-10-24): how the open Duo splits a list and
/// its detail.
///
/// - Flat: a native split, the list about a third and the detail the rest,
///   no fold gutter; the list can hide so the detail fills the display.
/// - Book: equal pages split at the fold with the gutter (`SpreadGeometry.pages`).
public enum DuoSplit {
    /// The list's share of the width when flat.
    public static let listShare = 1.0 / 3
    /// The narrowest the list column may be when flat.
    public static let minList = 260.0
    /// The narrowest the detail may be when flat.
    public static let minDetail = 400.0
    /// A list column narrower than this uses its narrow header (the Library's
    /// kind control collapses to one menu).
    public static let narrowList = 360.0

    /// Flat: the list (left) about a third, the detail (right) the rest, with
    /// no gap between them. `nil` when the detail would be under `minDetail`.
    public static func flatPages(width: Double) -> SpreadGeometry.Pages? {
        let list = max((width * listShare).rounded(), minList)
        guard width - list >= minDetail else { return nil }
        return SpreadGeometry.Pages(left: FoldColumns.Track(x: 0, width: list),
                                    right: FoldColumns.Track(x: list, width: width - list))
    }

    /// The pages for a posture: book splits at the fold (`SpreadGeometry.pages`),
    /// flat at a third. `fold` is the top-to-bottom fold (active or inactive);
    /// flat it only says the Duo is open, its x is not reserved.
    public static func pages(width: Double, fold: ClosedRange<Double>, posture: DuoPosture) -> SpreadGeometry.Pages? {
        switch posture {
        case .book:
            return SpreadGeometry.pages(width: width, fold: fold)
        case .flat:
            guard fold.lowerBound > 0, fold.upperBound < width else { return nil }
            return flatPages(width: width)
        }
    }

    /// Whether the list column hides: the tab remembers it hidden, the Duo is
    /// flat (`posture`, `nil` when not open) and a detail is beside the list.
    public static func hidesList(remembered: Bool, posture: DuoPosture?, detailShown: Bool) -> Bool {
        remembered && detailShown && posture?.canHideList == true
    }

    /// The list column is narrow enough for its narrow header.
    public static func isNarrowList(width: Double) -> Bool {
        width > 0 && width < narrowList
    }
}

/// Which tabs keep their list hidden on the open Duo (the sidebar button),
/// stored as one per-device string (`storageKey`), keyed by tab.
public struct DuoListMemory: Equatable, Sendable {
    public static let storageKey = "fusionha.duo.hiddenLists"

    public private(set) var hidden: Set<String>

    public init(raw: String) {
        hidden = Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    /// The stored form: the tab keys, sorted, comma separated.
    public var raw: String { hidden.sorted().joined(separator: ",") }

    public func isHidden(_ tab: String) -> Bool { hidden.contains(tab) }

    public mutating func set(_ isHidden: Bool, for tab: String) {
        if isHidden { hidden.insert(tab) } else { hidden.remove(tab) }
    }

    public mutating func toggle(_ tab: String) {
        set(!isHidden(tab), for: tab)
    }
}

/// The longest a line of reading text runs (overviews, taglines, section
/// text): about 680 pt, leading-aligned, so a title filling the open Duo
/// (list hidden) keeps lines near 90 characters instead of ~140. Art, heroes,
/// bars and grids stay full width.
public enum ReadableWidth {
    public static let max = 680.0

    /// The width a text block gets in a container `width` wide.
    public static func width(in width: Double) -> Double {
        Swift.min(width, max)
    }
}
