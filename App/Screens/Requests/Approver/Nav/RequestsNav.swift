import SwiftUI
import FusionhaKit

/// The approver's views (Final mock, 2026-10-18): one header row names the
/// current view and opens the drawer. Rules lives in Settings › Requests.
enum RequestsPane: String, CaseIterable, Hashable, Identifiable {
    case inbox, board, history, threads, issues, insights, mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .board: return "Board"
        case .history: return "History"
        case .threads: return "Threads"
        case .issues: return "Issues"
        case .insights: return "Insights"
        case .mine: return "Mine"
        }
    }

    var icon: String {
        switch self {
        case .inbox: return "tray"
        case .board: return "rectangle.split.3x1"
        case .history: return "list.bullet"
        case .threads: return "text.bubble"
        case .issues: return "exclamationmark.triangle"
        case .insights: return "chart.bar"
        case .mine: return "person"
        }
    }

    /// The filter sections this view offers; none hides the Filter button.
    var filters: Set<RequestsFilter.Section> {
        switch self {
        case .inbox: return [.requester, .source, .display]
        case .board: return [.search, .requester, .source, .density]
        case .history: return [.search, .status, .source]
        case .issues: return [.issueState]
        case .threads: return [.threadType, .issueState]
        case .mine: return [.mineType, .mineStatus, .source]
        case .insights: return []
        }
    }
}

/// What the header, the drawer and the filter sheet share: the current view,
/// its filters, the people seen (for Requester), and the live result count
/// the open view reports for "Show N requests".
@MainActor
@Observable
final class RequestsNav {
    var pane: RequestsPane = .inbox
    /// The views this person may open, in menu order (each gated on its own
    /// permission: requests.approve, issues.manage).
    var panes: [RequestsPane] = RequestsPane.allCases
    /// Inbox as cards or a list (Proposal 2), remembered on this device.
    var inboxList: Bool = UserDefaults.standard.bool(forKey: "requests.inbox.list") {
        didSet { UserDefaults.standard.set(inboxList, forKey: "requests.inbox.list") }
    }
    var filter = RequestsFilter()
    var menuOpen = false
    var filterOpen = false
    var rulesOpen = false
    /// Inbox: the deck or the "Select several" list.
    var selecting = false
    /// My requests' counts, for the Mine summary line.
    var mineCounts: RequestCounts?
    /// Threads offers Type only to someone who manages requests and issues.
    var threadTypes = true
    /// Requesters seen in the loaded rows, for the filter sheet.
    var people: [RequestPerson] = []
    /// The open view's row count under the current filters.
    var resultCount: Int?

    func open(_ pane: RequestsPane) {
        self.pane = pane
        selecting = false
        resultCount = nil
        menuOpen = false
    }

    func remember(_ rows: [MediaRequest]) {
        var known = Dictionary(uniqueKeysWithValues: people.compactMap { p in p.id.map { ($0, p) } })
        for r in rows { if let p = r.requester, let id = p.id { known[id] = p } }
        let sorted = known.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        if sorted != people { people = sorted }
    }
}

/// The filters one view applies, kept per view so switching views doesn't
/// carry a History status into the Board.
struct RequestsFilter: Equatable {
    enum Section: Hashable { case search, requester, source, density, status, display, issueState, threadType, mineType, mineStatus }

    struct Values: Equatable {
        var search = ""
        var requesterId: Int?
        var origins: Set<RequestOrigin> = []
        var compact = false
        var status: HistoryFilter = .all
        /// Issues and Threads: open · resolved · all.
        var issueState = "open"
        /// Threads: all · request · issue (only when the viewer manages both).
        var threadType = "all"
        /// Mine: my requests or my issues.
        var mineIssues = false
        /// Mine › Requests: Active · Available · All.
        var mineStatus: MyRequestsView.Filter = .active
    }

    private var byPane: [RequestsPane: Values] = [:]

    subscript(pane: RequestsPane) -> Values {
        get { byPane[pane] ?? Values() }
        set { byPane[pane] = newValue }
    }

    /// The number on the Filter button: set filters, not density.
    func activeCount(_ pane: RequestsPane) -> Int {
        let v = self[pane]
        var n = v.origins.count
        if v.requesterId != nil { n += 1 }
        if v.status != .all { n += 1 }
        if v.issueState != "open" { n += 1 }
        if v.threadType != "all" { n += 1 }
        if v.mineIssues { n += 1 }
        if v.mineStatus != .active { n += 1 }
        if !v.search.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        return n
    }

    /// Clears the filters and keeps the density (a display choice, not a filter).
    mutating func reset(_ pane: RequestsPane) {
        let compact = self[pane].compact
        self[pane] = Values(compact: compact)
    }

    /// `user_id` and `source` for the server, under the view's own search.
    func query(_ pane: RequestsPane) -> [URLQueryItem] {
        let v = self[pane]
        var items: [URLQueryItem] = []
        if let id = v.requesterId { items.append(URLQueryItem(name: "user_id", value: String(id))) }
        return items + RequestOrigin.query(v.origins)
    }
}
