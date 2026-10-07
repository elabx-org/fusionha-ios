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
        case .downloading: WidgetDownloadingPage(rows: entry.rows, total: entry.total, large: large)
        case .upNext: WidgetUpNextPage(rows: entry.upNext, large: large)
        case .recent: WidgetRecentPage(rows: entry.recent, large: large)
        case .library: WidgetLibraryPage(summary: data.library, wanted: data.wanted, large: large)
        case .indexers: WidgetIndexersPage(summary: data.indexers, large: large)
        case .wanted: WidgetWantedPage(summary: data.wanted, posters: data.wantedPosters, large: large)
        case .requests: WidgetRequestsPage(data: data, large: large)
        }
    }
}

extension DownloadsEntry {
    /// Combined speed of the listed downloads.
    var rate: Double? {
        let rates = rows.compactMap(\.rate)
        return rates.isEmpty ? nil : rates.reduce(0, +)
    }

    /// The header's one status figure for the current view.
    var pageFigure: String? {
        guard !failed, pageError == nil, !restricted else { return nil }
        let data = pageData
        switch page {
        case .downloading:
            guard !idle else { return nil }
            return ["\(total)", rate.map(WidgetDownloadStats.rateLabel)].compactMap { $0 }.joined(separator: " · ")
        case .upNext:
            return weekCount.flatMap { $0 > 0 ? "\($0) this week" : nil }
        case .recent:
            let today = recent.filter { row in row.item.importedAt.map { Calendar.current.isDateInToday($0) } ?? false }
            return today.isEmpty ? nil : "\(today.count) today"
        case .library:
            return data.library.map { $0.titles.formatted() }
        case .indexers:
            guard let s = data.indexers, s.total > 0 else { return nil }
            return "\(s.healthy)/\(s.total) healthy"
        case .wanted:
            return nil
        case .requests:
            guard let s = data.requests, s.pending > 0 else { return nil }
            return "\(s.pending) pending"
        }
    }
}
