import Foundation
import FusionhaKit

/// The data behind the paged widget's current view. Only the shown page's
/// part is filled, so a page flip fetches one view's worth of data.
struct WidgetPageData: Hashable {
    var library: WidgetLibrarySummary?
    var indexers: WidgetIndexerSummary?
    var wanted: WidgetWantedSummary?
    /// Posters for `wanted.rows`, in order.
    var wantedPosters: [Data?] = []
    var requests: WidgetRequestsSummary?
    /// Request id → title (from the TMDB preview).
    var requestTitles: [Int: String] = [:]
    /// User id → display name (user managers only; else `user #id`).
    var userNames: [Int: String] = [:]
    var issueTitle: String?
}
