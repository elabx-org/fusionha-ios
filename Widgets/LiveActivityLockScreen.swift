import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The Lock Screen (and StandBy) view, one layout per state, in the redesign's
/// language (mock "Live Activity, redesigned", 2026-10-16): one hero per state
/// in the display face, the poster's wash behind (`LiveActivityWash`), and the
/// HD / 4K chip that fills as it downloads. Every state fits the 160pt height.
struct LiveActivityLockScreen: View {
    typealias State = DownloadsActivityAttributes.ContentState
    let state: State
    let stale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state.mode {
            case .downloading:
                if state.downloading > 1 && state.rows.count > 1 { several } else { single }
            case .held: LiveActivityHeldView(state: state)
            case .problem: problem
            case .steps: steps
            case .imported, .upgraded, .done: landed
            }
            if stale {
                Text("updated \(Date(timeIntervalSince1970: state.updatedAt), style: .relative) ago")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: Downloading

    /// One title: the percentage is the hero; the version chip fills.
    @ViewBuilder
    private var single: some View {
        if let row = state.rows.first {
            HStack(spacing: 13) {
                LiveActivityPoster(mediaItemId: row.mediaItemId, width: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.system(size: 15.5, weight: .bold)).lineLimit(1)
                    if let sub = row.sub { meta(sub) }
                    HStack(spacing: 8) {
                        EditionFillChip(label: row.version, color: LiveActivityTone.version(row.version), fraction: row.fraction ?? 0)
                        if let rate = LiveActivityFormat.rate(state.bps) { meta(rate, size: 12) }
                    }
                    .padding(.top, 6)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 3) {
                    if let pct = LiveActivityFormat.percentNumber(row.fraction) {
                        LiveActivityHero(text: pct, size: 52, color: Theme.grab, unit: "%")
                    }
                    if let eta = LiveActivityFormat.eta(state.etaSeconds) { meta("\(eta) left", size: 12) }
                }
                .fixedSize()
            }
            if state.needYou > 0 { needYouLine }
        }
    }

    /// Several: total speed is the hero; a row per download, nearest to done.
    private var several: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let rate = LiveActivityFormat.rateParts(state.bps) {
                    LiveActivityHero(text: rate.number, size: 34, color: Theme.grab)
                    Text(rate.unit).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.grab)
                }
                Spacer(minLength: 6)
                meta(severalCaption, size: 12.5).lineLimit(1)
            }
            ForEach(state.rows.prefix(2), id: \.downloadId) { LiveActivityRowView(row: $0) }
        }
    }

    private var severalCaption: String {
        var parts = ["\(state.downloading) downloading"]
        if state.needYou > 0 { parts.append("\(state.needYou) need you") }
        return parts.joined(separator: " · ")
    }

    // MARK: Steps (symlink jobs)

    private var steps: some View {
        VStack(alignment: .leading, spacing: 11) {
            if let steps = state.steps {
                HStack(spacing: 13) {
                    if let row = state.rows.first { LiveActivityPoster(mediaItemId: row.mediaItemId, width: 48) }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            LiveActivityHero(text: steps.current ?? "Working", size: 32)
                            Spacer(minLength: 6)
                            meta("\(min(steps.done + 1, steps.labels.count)) of \(steps.labels.count)")
                        }
                        if let row = state.rows.first { titleLine(row.title, sub: row.sub, version: row.version) }
                    }
                }
                LiveActivityStageRail(steps: steps)
            }
        }
    }

    // MARK: Problem

    private var problem: some View {
        VStack(alignment: .leading, spacing: 11) {
            if let event = state.event {
                let stalled = event.detail?.hasPrefix("Stalled") == true
                HStack(spacing: 13) {
                    LiveActivityPoster(mediaItemId: event.mediaItemId, width: 48).saturation(0.6)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            LiveActivityHero(text: stalled ? "Stalled" : "Failed", size: 32, color: Theme.danger)
                            if stalled, let at = event.detail?.replacingOccurrences(of: "Stalled ", with: "") { meta(at) }
                        }
                        titleLine(event.title, sub: nil, version: event.version)
                        meta(problemLine(event, stalled: stalled), size: 12).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    if let id = event.downloadId {
                        Button(intent: LiveActivitySearchAgainIntent(downloadId: id)) {
                            Label("Search again", systemImage: "magnifyingglass").capsule(Theme.danger.opacity(0.26))
                        }
                        .buttonStyle(.plain)
                    }
                    if let link = URL(string: "fusionha://activity" + (event.downloadId.map { "?focus=\($0)" } ?? "")) {
                        Link(destination: link) { Text("Open queue").capsule(Color.white.opacity(0.1)) }
                    }
                }
            }
        }
    }

    private func problemLine(_ event: State.Event, stalled: Bool) -> String {
        var parts: [String] = []
        if !stalled, let detail = event.detail { parts.append(detail) }
        if let line2 = event.line2 { parts.append(line2) }
        if state.downloading > 1 { parts.append("\(state.downloading - 1) more downloading") }
        return parts.joined(separator: " · ")
    }

    // MARK: Landed

    private var landed: some View {
        let upgraded = state.mode == .upgraded
        let tone = upgraded ? Theme.edition : Theme.done
        return HStack(spacing: 13) {
            if let event = state.event {
                LiveActivityPoster(mediaItemId: event.mediaItemId, width: 56)
                VStack(alignment: .leading, spacing: 5) {
                    LiveActivityHero(text: upgraded ? "Upgraded" : (state.mode == .done ? "All done" : "On disk"), size: 32)
                    HStack(spacing: 6) {
                        Text(event.title).font(.system(size: 15.5, weight: .bold)).lineLimit(1)
                        if let ep = event.line2 { meta(ep, size: 12) }
                    }
                    HStack(spacing: 8) {
                        EditionFillChip(label: event.version + " ✓", color: tone, fraction: 1)
                        if let detail = event.detail, !detail.isEmpty { meta(detail, size: 12).lineLimit(1) }
                    }
                }
                Spacer(minLength: 0)
            } else {
                LiveActivityHero(text: "All done", size: 32, color: tone)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Parts

    private func titleLine(_ title: String, sub: String?, version: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 14.5, weight: .bold)).lineLimit(1)
            if let sub { meta(sub, size: 12).lineLimit(1) }
            EditionFillChip(label: version, color: LiveActivityTone.version(version))
        }
    }

    private func meta(_ text: String, size: CGFloat = 13) -> Text {
        Text(text).font(.system(size: size, weight: .medium).monospacedDigit()).foregroundColor(.white.opacity(0.62))
    }

    private var needYouLine: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.miss).frame(width: 7, height: 7)
            Text("\(state.needYou) need you · held for review")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.miss)
        }
    }
}

private extension View {
    /// A Live Activity action capsule.
    func capsule(_ fill: Color) -> some View {
        font(.system(size: 13.5, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(fill, in: Capsule())
    }
}

/// One download among several: poster, title, episode, its own bar and %.
struct LiveActivityRowView: View {
    let row: DownloadsActivityAttributes.ContentState.Row

    var body: some View {
        HStack(spacing: 10) {
            LiveActivityPoster(mediaItemId: row.mediaItemId, width: 30)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                    if let sub = row.sub {
                        Text(sub).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    }
                }
                ProgressView(value: row.fraction ?? 0)
                    .tint(LiveActivityTone.version(row.version))
            }
            if let pct = LiveActivityFormat.percentNumber(row.fraction) {
                LiveActivityHero(text: pct + "%", size: 24).frame(minWidth: 52, alignment: .trailing)
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
        .clipShape(RoundedRectangle(cornerRadius: width > 40 ? 7 : 5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: width > 40 ? 7 : 5, style: .continuous)
            .strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
    }
}
