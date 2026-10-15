import ActivityKit
import SwiftUI
import WidgetKit

// The Dynamic Island: compact (count · soonest finish), minimal (the
// leading download's ring), and expanded on a long press.

typealias LAState = DownloadsActivityAttributes.ContentState

struct LiveActivityCompactLeading: View {
    let state: LAState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(LiveActivityTone.of(state))
            if let count { Text("\(count)").font(.system(size: 14, weight: .bold).monospacedDigit()) }
        }
    }

    private var icon: String {
        switch state.mode {
        case .held: return "pause.circle.fill"
        case .problem: return "exclamationmark.triangle.fill"
        case .imported, .done: return "checkmark.circle.fill"
        case .upgraded: return "arrow.up.circle.fill"
        case .steps: return "link.circle.fill"
        case .downloading: return "arrow.down.circle.fill"
        }
    }

    private var count: Int? {
        switch state.mode {
        case .held: return state.needYou
        case .downloading, .problem, .steps: return state.downloading
        default: return nil
        }
    }
}

struct LiveActivityCompactTrailing: View {
    let state: LAState

    var body: some View {
        Group {
            switch state.mode {
            case .held: Text("need you").foregroundStyle(Theme.miss)
            case .problem: Text("stalled").foregroundStyle(Theme.danger)
            case .imported, .upgraded, .done: Text("done").foregroundStyle(Theme.done)
            case .steps: Text(state.steps.map { "\(min($0.done + 1, $0.labels.count))/\($0.labels.count)" } ?? "")
            case .downloading:
                Text(LiveActivityFormat.eta(state.etaSeconds) ?? LiveActivityFormat.percent(state.rows.first?.fraction) ?? "")
            }
        }
        .font(.system(size: 13, weight: .semibold).monospacedDigit())
    }
}

struct LiveActivityMinimal: View {
    let state: LAState

    var body: some View {
        if let fraction = state.rows.first?.fraction, state.mode == .downloading {
            ProgressView(value: fraction)
                .progressViewStyle(.circular)
                .tint(LiveActivityTone.version(state.rows.first?.version ?? ""))
        } else {
            LiveActivityCompactLeading(state: state)
        }
    }
}

struct LiveActivityIslandLeading: View {
    let state: LAState

    var body: some View {
        if let id = state.rows.first?.mediaItemId ?? state.event?.mediaItemId ?? state.held.first?.mediaItemId {
            LiveActivityPoster(mediaItemId: id, width: 36)
        }
    }
}

struct LiveActivityIslandTrailing: View {
    let state: LAState

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if state.mode == .downloading, let eta = LiveActivityFormat.eta(state.etaSeconds) {
                Text(eta).font(.system(size: 17, weight: .bold).monospacedDigit())
                Text("left").font(.system(size: 11)).foregroundStyle(.secondary)
            } else if state.mode == .held {
                Text("\(state.needYou)").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.miss)
                Text("need you").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}

struct LiveActivityIslandCenter: View {
    let state: LAState

    var body: some View {
        let title = state.rows.first?.title ?? state.event?.title ?? state.held.first?.title ?? "Downloads"
        let version = state.rows.first?.version ?? state.event?.version
        HStack(spacing: 6) {
            Text(title).font(.system(size: 15, weight: .bold)).lineLimit(1)
            if let version {
                Text(version).font(.system(size: 12, weight: .bold)).foregroundStyle(LiveActivityTone.version(version)).fixedSize()
            }
        }
    }
}

struct LiveActivityIslandBottom: View {
    let state: LAState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch state.mode {
            case .downloading:
                if let row = state.rows.first, let fraction = row.fraction {
                    ProgressView(value: fraction).tint(LiveActivityTone.version(row.version))
                }
                Text(line).font(.system(size: 12)).foregroundStyle(.secondary)
            case .held:
                if let held = state.held.first {
                    Text("\(held.count > 1 ? "\(held.count) episodes · " : "")\(held.reason)")
                        .font(.system(size: 13)).foregroundStyle(Theme.miss)
                }
                if let link = LiveActivityLinks.review(state.held.flatMap(\.downloadIds)) {
                    Link("Review in Manual Import", destination: link).font(.system(size: 13, weight: .semibold))
                }
            case .problem:
                if let detail = state.event?.detail {
                    Text(detail).font(.system(size: 13)).foregroundStyle(Theme.danger)
                }
                if let id = state.event?.downloadId {
                    Button(intent: LiveActivitySearchAgainIntent(downloadId: id)) {
                        Label("Search again", systemImage: "magnifyingglass")
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
            case .steps:
                if let steps = state.steps {
                    Text(steps.labels.joined(separator: " → ")).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
            case .imported, .upgraded, .done:
                if let detail = state.event?.detail, !detail.isEmpty {
                    Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var line: String {
        let pct = LiveActivityFormat.percent(state.rows.first?.fraction)
        let rate = LiveActivityFormat.rate(state.bps)
        let more = state.downloading > 1 ? "+\(state.downloading - 1) downloading" : nil
        let need = state.needYou > 0 ? "\(state.needYou) need you" : nil
        return [pct, rate, more, need].compactMap { $0 }.joined(separator: " · ")
    }
}
