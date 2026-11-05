import SwiftUI
import FusionhaKit

/// The Library's persisted filters as one bundle of bindings, so the v2
/// controls (the F1 row, its menu, the tokens, the section head and the
/// no-match state) share them without long parameter lists. The values live
/// in the page's `@AppStorage`, under v1's keys.
struct V2LibraryFilters {
    @Binding var kind: String
    @Binding var tier: LibraryTier
    @Binding var status: LibraryStatus
    @Binding var sort: LibrarySort
    @Binding var recency: LibraryRecency
    @Binding var group: Bool
    @Binding var density: String
    /// Show › Not monitored (v2 only, owner's monitor mark M1): only the
    /// titles that are switched off. Combines with the status filter.
    @Binding var unmonitored: Bool

    var compact: Bool { density == "compact" }

    /// The filters set through the Filter menu, as removable tokens (F1:
    /// shown only when set). Tier and kind have their own controls, and the
    /// sort shows in the section head.
    var tokens: [V2LibraryToken] {
        var out: [V2LibraryToken] = []
        if status != .all { out.append(.status(status)) }
        if unmonitored { out.append(.unmonitored) }
        if recency != .all { out.append(.recency(recency)) }
        if group { out.append(.group) }
        return out
    }

    func remove(_ token: V2LibraryToken) {
        switch token {
        case .status: status = .all
        case .unmonitored: unmonitored = false
        case .recency: recency = .all
        case .group: group = false
        }
    }

    /// Reset filters: everything the menu sets, back to its default.
    func reset() {
        status = .all
        unmonitored = false
        recency = .all
        group = false
        sort = .title
    }

    /// The no-match state's Clear: every filter, the kind and tier too.
    func clearAll() {
        reset()
        kind = "all"
        tier = .all
    }
}

/// One active filter, shown as a token under the F1 row.
enum V2LibraryToken: Hashable, Identifiable {
    case status(LibraryStatus)
    case unmonitored
    case recency(LibraryRecency)
    case group

    var id: String {
        switch self {
        case .status(let s): return "status-\(s.rawValue)"
        case .unmonitored: return "unmonitored"
        case .recency(let r): return "recency-\(r.rawValue)"
        case .group: return "group"
        }
    }

    var label: String {
        switch self {
        case .status(let s): return s.v2Label
        case .unmonitored: return "Not monitored"
        case .recency(.added): return "Added · 30 days"
        case .recency(.released): return "Released · 30 days"
        case .recency(.all): return "Any time"
        case .group: return "Grouped by status"
        }
    }

    var systemImage: String {
        switch self {
        case .status(let s): return s.v2Symbol
        case .unmonitored: return "bookmark.slash"
        case .recency: return "clock"
        case .group: return "list.bullet.indent"
        }
    }
}

extension LibraryStatus {
    /// The Filter menu's word for the status filter.
    var v2Label: String {
        switch self {
        case .all: return "Everything"
        case .downloading: return "Downloading"
        case .missing: return "Missing"
        case .upcoming: return "Upcoming"
        case .complete: return "Complete"
        case .attention: return "Needs attention"
        }
    }

    var v2Symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .downloading: return "arrow.down.circle"
        case .missing: return "circle.dashed"
        case .upcoming: return "clock"
        case .complete: return "checkmark.circle"
        case .attention: return "exclamationmark.triangle"
        }
    }

    /// The Show section's order in the Filter menu.
    static let v2MenuOrder: [LibraryStatus] = [.missing, .attention, .downloading, .upcoming, .complete]
}
