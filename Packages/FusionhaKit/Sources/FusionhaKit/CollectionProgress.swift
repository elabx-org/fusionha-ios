import Foundation

/// A film's place in its collection (CollectionCompletionRail's `segState`,
/// StatusBadge's `partBadgeStatus`).
public enum CollectionPartState: String, Sendable, Hashable {
    case present, tracked, missing

    public init(_ part: CollectionPart) {
        if part.owned != true { self = .missing } else { self = part.hasFile == true ? .present : .tracked }
    }
}

/// The counts and copy the Collection tab header and the "N of M ›" rail share.
public struct CollectionProgress: Sendable, Equatable {
    public let present: Int
    public let tracked: Int
    public let missing: Int
    public let total: Int

    public init(_ detail: CollectionDetail) {
        // The server's counts skip ignored films; fall back to the parts.
        let partPresent = detail.parts.filter { CollectionPartState($0) == .present }.count
        present = detail.presentCount ?? partPresent
        tracked = max(detail.ownedCount - present, 0)
        missing = detail.parts.filter { $0.owned != true }.count
        total = detail.totalCount
    }

    /// The rail header link: `present of total ›`.
    public var railLink: String { "\(present) of \(total) ›" }

    /// The completion rail's accessibility label.
    public static func railLabel(_ parts: [CollectionPart]) -> String {
        let states = parts.map(CollectionPartState.init)
        let present = states.filter { $0 == .present }.count
        let tracked = states.filter { $0 == .tracked }.count
        let missing = parts.count - present - tracked
        var out = "\(present) of \(parts.count) present"
        if tracked > 0 { out += ", \(tracked) tracked with no file yet" }
        if missing > 0 { out += ", \(missing) missing" }
        return out
    }

    /// The tmdb ids "Add all missing" preselects.
    public static func missingIds(_ detail: CollectionDetail) -> [Int] {
        detail.parts.filter { $0.owned != true }.map(\.tmdbId)
    }

    /// The ids a rail poster's "Add to library" opens with: just this film when
    /// it is missing, every missing film otherwise (DetailRailStack).
    public static func addIds(for part: CollectionPart, in detail: CollectionDetail) -> [Int] {
        part.owned == true ? missingIds(detail) : [part.tmdbId]
    }

    /// Library ids of the owned films (the "Monitor" toggle's targets).
    public static func ownedLibraryIds(_ detail: CollectionDetail) -> [Int] {
        detail.parts.filter { $0.owned == true }.compactMap(\.libraryItemId)
    }
}
