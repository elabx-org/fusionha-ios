import SwiftUI
import WidgetKit
import FusionhaKit

/// Up next: small shows the next airing alone; medium and large are the
/// shared Up next view under the compact header.
struct UpNextWidgetView: View {
    let entry: UpNextEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.signedIn {
                WidgetSignInPrompt(report: "")
            } else if family == .systemSmall, let next = entry.rows.first {
                WidgetUpNextSmall(row: next)
            } else if family == .systemSmall, entry.failed {
                WidgetSmallFailure(title: "Up next")
            } else {
                VStack(alignment: .leading, spacing: WidgetStyle.headerGap) {
                    WidgetTopBar(title: "Up next", figure: entry.weekCount.flatMap { $0 > 0 ? "\($0) this week" : nil })
                    content.frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        if entry.failed {
            WidgetRetryLine(text: "Server unreachable", intent: ReloadWidgetIntent(kind: WidgetStack.kind(for: .upNext)))
        } else {
            WidgetUpNextPage(rows: entry.rows, large: family == .systemLarge)
        }
    }
}
