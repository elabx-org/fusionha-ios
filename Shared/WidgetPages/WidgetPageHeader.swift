import SwiftUI
import WidgetKit
import FusionhaKit

/// The paged widget's header: the view's icon and name (the download count on
/// Downloading, with Process queue), and the page dots.
struct WidgetPageHeader: View {
    let entry: DownloadsEntry
    let pages: [WidgetPage]
    let familyKey: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.page.icon)
                .foregroundStyle(entry.page.tint)
                .widgetAccentable()
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .widgetAccentable()
            if entry.page == .downloading { ProcessQueueButton() }
            Spacer(minLength: 4)
            if pages.count > 1 {
                WidgetPageDots(pages: pages, current: entry.page, familyKey: familyKey)
            }
        }
    }

    private var title: String {
        entry.page == .downloading ? "\(entry.total) downloading" : entry.page.title
    }
}

extension WidgetPage {
    var icon: String {
        switch self {
        case .downloading: return "arrow.down.circle.fill"
        case .upNext: return "calendar"
        case .recent: return "sparkles.tv"
        case .library: return "square.stack.fill"
        case .indexers: return "antenna.radiowaves.left.and.right"
        case .wanted: return "exclamationmark.magnifyingglass"
        case .requests: return "tray.full.fill"
        }
    }

    var tint: Color {
        switch self {
        case .downloading: return Theme.grab
        case .upNext: return Theme.unaired
        case .recent: return Theme.done
        case .library: return Theme.i2
        case .indexers: return Theme.indigo
        case .wanted: return Theme.miss
        case .requests: return Theme.edition
        }
    }
}
