import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The Lock Screen (and StandBy) view, one layout per state.
struct LiveActivityLockScreen: View {
    typealias State = DownloadsActivityAttributes.ContentState
    let state: State
    let stale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state.mode {
            case .downloading: downloading
            case .held: held
            case .problem: problem
            case .steps: steps
            case .imported, .upgraded, .done: landed
            }
            if stale {
                Text("updated \(Date(timeIntervalSince1970: state.updatedAt), style: .relative) ago")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: States

    private var downloading: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(title: "\(state.downloading) downloading", tone: Theme.grab,
                   trailing: [LiveActivityFormat.rate(state.bps), LiveActivityFormat.eta(state.etaSeconds).map { "next \($0)" }]
                       .compactMap { $0 }.joined(separator: "  "))
            ForEach(state.rows, id: \.downloadId) { LiveActivityRowView(row: $0) }
            if state.needYou > 0 { needYouLine }
        }
    }

    private var held: some View { LiveActivityHeldView(state: state) }

    private var problem: some View {
        VStack(alignment: .leading, spacing: 9) {
            header(title: state.event?.detail?.hasPrefix("Stalled") == true ? "1 stalled" : "Needs attention", tone: Theme.danger,
                   trailing: state.downloading > 1
                       ? (["\(state.downloading - 1) downloading", LiveActivityFormat.rate(state.bps)].compactMap { $0 }.joined(separator: " · "))
                       : "")
            if let event = state.event {
                HStack(alignment: .top, spacing: 10) {
                    LiveActivityPoster(mediaItemId: event.mediaItemId)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                        Text(event.version).font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LiveActivityTone.version(event.version))
                        if let detail = event.detail {
                            Text(detail + (event.line2.map { " · \($0)" } ?? ""))
                                .font(.system(size: 13)).foregroundStyle(Theme.danger).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let id = event.downloadId {
                    Button(intent: LiveActivitySearchAgainIntent(downloadId: id)) {
                        Label("Search again", systemImage: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                    }
                    .buttonStyle(.plain)
                    .background(Theme.danger.opacity(0.28), in: Capsule())
                }
            }
            if state.needYou > 1 { needYouLine }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let steps = state.steps {
                header(title: steps.current ?? "Working", tone: Theme.grab,
                       trailing: "step \(min(steps.done + 1, steps.labels.count)) of \(steps.labels.count)")
                if let row = state.rows.first {
                    HStack(spacing: 10) {
                        LiveActivityPoster(mediaItemId: row.mediaItemId)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                            Text([row.sub, row.version].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LiveActivityTone.version(row.version))
                        }
                    }
                }
                HStack(spacing: 4) {
                    ForEach(Array(steps.labels.enumerated()), id: \.offset) { index, label in
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(index < steps.done ? Theme.done.opacity(0.3)
                                        : (index == steps.done ? Theme.grab.opacity(0.35) : Color.white.opacity(0.08)),
                                        in: Capsule())
                    }
                }
                Text("Linked by decypharr · symlink jobs finish in seconds")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var landed: some View {
        let upgraded = state.mode == .upgraded
        return VStack(alignment: .leading, spacing: 9) {
            header(title: upgraded ? "Upgraded" : (state.mode == .done ? "All done" : "Imported"),
                   tone: upgraded ? Theme.edition : Theme.done, trailing: "",
                   icon: upgraded ? "arrow.up.circle.fill" : "checkmark.circle.fill")
            if let event = state.event {
                HStack(alignment: .top, spacing: 10) {
                    LiveActivityPoster(mediaItemId: event.mediaItemId)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                        Text([event.line2, event.version].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LiveActivityTone.version(event.version))
                        if let detail = event.detail, !detail.isEmpty {
                            Text(detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: Parts

    private var needYouLine: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.miss).frame(width: 7, height: 7)
            Text("\(state.needYou) need you · held for Manual Import")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.miss)
        }
    }

    private func header(title: String, tone: Color, trailing: String, icon: String? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon ?? glyph).font(.system(size: 15, weight: .bold)).foregroundStyle(tone)
            Text(title).font(.system(size: 17, weight: .bold))
            Spacer(minLength: 6)
            Text(trailing).font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7)).lineLimit(1)
        }
    }

    private var glyph: String {
        switch state.mode {
        case .held: return "pause.circle.fill"
        case .problem: return "exclamationmark.triangle.fill"
        case .steps: return "link.circle.fill"
        default: return "arrow.down.circle.fill"
        }
    }
}

/// One download: poster, title, version, its own bar and percent.
struct LiveActivityRowView: View {
    let row: DownloadsActivityAttributes.ContentState.Row

    var body: some View {
        HStack(spacing: 10) {
            LiveActivityPoster(mediaItemId: row.mediaItemId)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(row.title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                    Text(row.version).font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LiveActivityTone.version(row.version))
                        .fixedSize()
                    Spacer(minLength: 4)
                    if let pct = LiveActivityFormat.percent(row.fraction) {
                        Text(pct).font(.system(size: 13, weight: .bold).monospacedDigit())
                    }
                }
                if let sub = row.sub {
                    Text(sub).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                if let fraction = row.fraction {
                    ProgressView(value: fraction).tint(LiveActivityTone.version(row.version))
                }
            }
        }
    }
}

/// The small poster the app saved to the App Group, or a tile.
struct LiveActivityPoster: View {
    let mediaItemId: Int
    var width: CGFloat = 32

    var body: some View {
        Group {
            if let data = DownloadsActivityAttributes.ContentState.posterData(mediaItemId: mediaItemId),
               let image = UIImage(data: data) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color.white.opacity(0.12))
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

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
