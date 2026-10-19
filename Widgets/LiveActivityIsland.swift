import ActivityKit
import SwiftUI
import WidgetKit
import FusionhaKit

// The Dynamic Island: compact (count · soonest finish), minimal (the
// leading download's ring), and expanded on a long press.

typealias LAState = DownloadsActivityAttributes.ContentState

struct LiveActivityCompactLeading: View {
    let state: LAState

    var body: some View {
        if state.mode == .downloading, let row = state.rows.first, let fraction = row.fraction {
            // The poster in a progress ring (redesign mock, Dynamic Island).
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 2.5)
                Circle().trim(from: 0, to: fraction)
                    .stroke(Theme.grab, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                LiveActivityPoster(mediaItemId: row.mediaItemId, width: 17)
                    .clipShape(Circle())
                    .frame(width: 17, height: 17)
            }
            .frame(width: 24, height: 24)
        } else {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(LiveActivityTone.of(state))
                if let count { Text("\(count)").font(.system(size: 14, weight: .bold).monospacedDigit()) }
            }
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
                if let pct = LiveActivityFormat.percent(state.rows.first?.fraction) {
                    Text(pct).font(Theme.display(17, relativeTo: .headline)).foregroundStyle(Theme.grab)
                } else {
                    Text(LiveActivityFormat.eta(state.etaSeconds) ?? "")
                }
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
            LiveActivityPoster(mediaItemId: id, width: 40)
        }
    }
}

struct LiveActivityIslandTrailing: View {
    let state: LAState

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if state.mode == .downloading, let pct = LiveActivityFormat.percentNumber(state.rows.first?.fraction) {
                LiveActivityHero(text: pct, size: 40, color: Theme.grab, unit: "%")
                if let eta = LiveActivityFormat.eta(state.etaSeconds) {
                    Text("\(eta) left").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            } else if state.mode == .held {
                LiveActivityHero(text: "\(state.needYou)", size: 30, color: Theme.miss)
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
                HStack(spacing: 8) {
                    if let row = state.rows.first {
                        EditionFillChip(label: LiveActivityTone.shortVersion(row.version), color: LiveActivityTone.version(row.version), fraction: row.fraction ?? 0,
                                        mono: LiveActivityTone.versionToken(row.version))
                    }
                    Text(line).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
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
        let sub = state.rows.first?.sub
        let rate = LiveActivityFormat.rate(state.bps)
        let more = state.downloading > 1 ? "+\(state.downloading - 1) downloading" : nil
        let need = state.needYou > 0 ? "\(state.needYou) need you" : nil
        return [sub, rate, more, need].compactMap { $0 }.joined(separator: " · ")
    }
}
