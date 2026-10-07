import SwiftUI
import WidgetKit
import FusionhaKit

/// The Downloads widget. Small shows the top download, or what's up next / just
/// added when idle; medium and large are the paged view (`PagedDownloadsView`).
struct DownloadsWidgetView: View {
    let entry: DownloadsEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.signedIn {
                WidgetSignInPrompt(report: entry.report)
            } else if family != .systemSmall {
                PagedDownloadsView(entry: entry, family: family)
            } else if entry.failed {
                WidgetSmallFailure(title: "Downloads")
            } else if !entry.idle {
                WidgetDownloadingSmall(entry: entry)
            } else if let next = entry.upNext.first {
                WidgetUpNextSmall(row: next)
            } else if let latest = entry.recent.first {
                WidgetRecentSmall(row: latest)
            } else {
                WidgetDownloadingSmall(entry: entry)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// A small widget whose load failed: its header, the state in plain words and
/// that it retries on its own. The technical reason (`timeout @page library
/// 8.0s`) stays in the run journal (Widget diagnostics), not on the widget.
struct WidgetSmallFailure: View {
    let title: String
    var text = "Couldn't reach fusionha"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: title)
            WidgetStatusMessage(icon: "wifi.exclamationmark", text: text, detail: "Will retry soon")
        }
    }
}

/// Process queue: asks fusionha to check its download clients now.
struct ProcessQueueButton: View {
    var body: some View {
        Button(intent: ProcessQueueIntent()) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Process queue now")
    }
}
