import AppIntents
import SwiftUI
import WidgetKit

/// Apple Watch Smart Stack (and other small surfaces): one line of each.
struct LiveActivitySmall: View {
    let state: DownloadsActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            switch state.mode {
            case .problem:
                Text(state.event?.detail?.hasPrefix("Stalled") == true ? "1 stalled" : "Needs attention").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.danger)
                if let e = state.event { Text(e.title).font(.system(size: 13, weight: .semibold)).lineLimit(1) }
                if let id = state.event?.downloadId {
                    Button(intent: LiveActivitySearchAgainIntent(downloadId: id)) { Text("Search again") }
                        .font(.system(size: 12, weight: .semibold))
                }
            case .held:
                Text("\(state.needYou) need you").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.miss)
                if let h = state.held.first { Text(h.title).font(.system(size: 12)).lineLimit(1) }
            case .imported, .upgraded, .done:
                Text(state.mode == .upgraded ? "Upgraded" : "Imported").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LiveActivityTone.of(state))
                if let e = state.event { Text(e.title).font(.system(size: 12)).lineLimit(1) }
            default:
                if let row = state.rows.first {
                    HStack(spacing: 4) {
                        Text(row.title).font(.system(size: 13, weight: .bold)).lineLimit(1)
                        Text(row.version).font(.system(size: 11, weight: .bold)).foregroundStyle(LiveActivityTone.version(row.version))
                        Spacer(minLength: 0)
                        if let eta = LiveActivityFormat.eta(state.etaSeconds) { Text(eta).font(.system(size: 12).monospacedDigit()) }
                    }
                    if let f = row.fraction { ProgressView(value: f).tint(LiveActivityTone.version(row.version)) }
                }
                Text([state.downloading > 1 ? "+\(state.downloading - 1) downloading" : nil,
                      state.needYou > 0 ? "\(state.needYou) need you" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}
