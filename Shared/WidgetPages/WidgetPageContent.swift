import SwiftUI
import WidgetKit
import FusionhaKit

/// One view's medium or large content, shared by the paged Downloads widget
/// and the single-view Smart Stack widgets. A page whose data didn't arrive
/// shows its retry line instead (the paged widget's re-shows the page; a stack
/// widget's reloads itself).
struct WidgetPageContent: View {
    let entry: DownloadsEntry
    let large: Bool
    /// The paged widget's family key; nil on a stack widget.
    var familyKey: String?

    var body: some View {
        if entry.failed || entry.pageError != nil {
            failure
        } else if entry.restricted {
            WidgetStatusMessage(icon: "lock.fill", text: "For approvers",
                                detail: "Requests & issues need approve or issue rights.")
        } else {
            content
        }
    }

    @ViewBuilder
    private var failure: some View {
        let text = entry.failed ? "Server unreachable" : "Couldn't load"
        if let familyKey {
            WidgetRetryLine(text: text, diagnostic: entry.diagnostic,
                            intent: SetWidgetPageIntent(family: familyKey, page: entry.page))
        } else {
            WidgetRetryLine(text: text, diagnostic: entry.diagnostic,
                            intent: ReloadWidgetIntent(kind: WidgetStack.kind(for: entry.page)))
        }
    }

    @ViewBuilder
    private var content: some View {
        let data = entry.pageData
        switch entry.page {
        case .downloading: WidgetDownloadingPage(rows: entry.rows, large: large)
        case .upNext: WidgetUpNextPage(rows: entry.upNext, large: large)
        case .recent: WidgetRecentPage(rows: entry.recent, large: large)
        case .library: WidgetLibraryPage(summary: data.library, large: large)
        case .indexers: WidgetIndexersPage(summary: data.indexers, large: large)
        case .wanted: WidgetWantedPage(summary: data.wanted, posters: data.wantedPosters, large: large)
        case .requests: WidgetRequestsPage(data: data, large: large)
        }
    }
}

extension DownloadsEntry {
    /// The header's status figure for the current view, and its colour.
    var pageFigure: (text: String, tint: Color)? {
        guard !failed, pageError == nil else { return nil }
        switch page {
        case .downloading:
            return idle ? nil : ("\(total)", Theme.grab)
        case .recent:
            let fresh = recent.filter { row in
                row.item.importedAt.map { Date.now.timeIntervalSince($0) < 86_400 } ?? false
            }.count
            return fresh > 0 ? ("\(fresh) new", Theme.done) : nil
        case .indexers:
            guard let s = pageData.indexers, s.total > 0 else { return nil }
            return ("\(s.healthy)/\(s.total)", s.healthy < s.total ? Theme.stuck : Theme.done)
        default:
            return nil
        }
    }
}
