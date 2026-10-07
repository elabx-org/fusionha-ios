import SwiftUI
import WidgetKit
import FusionhaKit

/// A single-view Smart Stack widget (Downloading, Library, Indexers, Requests
/// & issues). Small has its own one-thing layout; medium and large are the
/// paged widget's view under the same compact header, without the dots.
struct WidgetStackView: View {
    let entry: DownloadsEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.signedIn {
                WidgetSignInPrompt(report: entry.report)
            } else if family == .systemSmall {
                small
            } else {
                VStack(alignment: .leading, spacing: WidgetStyle.headerGap) {
                    header
                    WidgetPageContent(entry: entry, large: family == .systemLarge)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        return WidgetTopBar(title: entry.page.title, figure: entry.pageFigure) {
            if entry.page == .downloading { ProcessQueueButton() }
        }
    }

    @ViewBuilder
    private var small: some View {
        let data = entry.pageData
        if entry.failed || entry.pageError != nil {
            WidgetSmallFailure(title: entry.page.title, text: entry.failed ? "Couldn't reach fusionha" : "Couldn't load")
        } else if entry.restricted {
            VStack(alignment: .leading, spacing: 0) {
                WidgetTopBar(title: "Requests")
                WidgetStatusMessage(icon: "lock.fill", text: "For approvers")
            }
        } else {
            switch entry.page {
            case .library:
                if let s = data.library { WidgetLibrarySmall(summary: s) } else { unavailable }
            case .indexers:
                if let s = data.indexers { WidgetIndexersSmall(summary: s) } else { unavailable }
            case .requests:
                if let s = data.requests { WidgetRequestsSmall(summary: s) } else { unavailable }
            default:
                WidgetDownloadingSmall(entry: entry)
            }
        }
    }

    private var unavailable: some View {
        WidgetSmallFailure(title: entry.page.title, text: "Couldn't load")
    }
}
