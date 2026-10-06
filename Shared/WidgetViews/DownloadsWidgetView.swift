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
                VStack(alignment: .leading) {
                    DownloadsSmallHeader(entry: entry)
                    WidgetEmptyText("Server unreachable")
                }
            } else if entry.idle {
                idleSmall
            } else {
                activeSmall
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var activeSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            DownloadsSmallHeader(entry: entry)
            Spacer(minLength: 0)
            if let row = entry.rows.first {
                Text(row.title).font(.caption.weight(.semibold)).lineLimit(2)
                WidgetTierPill(tier: row.tier, status: row.stalled ? .stuck : .downloading)
                ProgressView(value: row.fraction).tint(row.stalled ? Theme.stuck : Theme.grab)
            }
        }
    }

    private var idleSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            DownloadsSmallHeader(entry: entry)
            if let next = entry.upNext.first {
                WidgetSectionLabel("Up next")
                Spacer(minLength: 0)
                WidgetUpNextHero(row: next, posterWidth: 0)
            } else if let latest = entry.recent.first {
                WidgetSectionLabel("Recently added")
                Spacer(minLength: 0)
                WidgetRecentHero(row: latest, posterWidth: 0)
            } else {
                WidgetEmptyText("Nothing downloading")
            }
        }
    }
}

/// `Idle` / `3 downloading` and the Process queue button.
struct DownloadsSmallHeader: View {
    let entry: DownloadsEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.idle ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(entry.idle ? Theme.done : Theme.grab)
                .widgetAccentable()
            Text(entry.idle ? "Idle" : "\(entry.total) downloading")
                .font(.caption.weight(.semibold))
                .widgetAccentable()
            Spacer(minLength: 0)
            ProcessQueueButton()
        }
    }
}

struct ProcessQueueButton: View {
    var body: some View {
        Button(intent: ProcessQueueIntent()) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Process queue now")
    }
}
