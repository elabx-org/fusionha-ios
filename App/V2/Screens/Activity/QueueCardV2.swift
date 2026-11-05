import SwiftUI
import FusionhaKit

/// A v2 queue card (plan S8, mock activity.js `qcard`): one poster, the
/// title and the time it was grabbed, what it is, then one lane per version
/// (a 4K + HD pair shares the card). No colour wash: the state is in the T5
/// badges and the one-ink bars. A row of a W1 module, not a card of its own.
struct QueueCardV2: View {
    let downloads: [QueueItem]
    let telemetry: [Int: QueueTelemetry]
    /// Select mode: the check before the poster (nil when not selecting).
    var checked: Bool?
    /// A group of one version's downloads (a season's episodes) shows the
    /// first few lanes, then how many more.
    var maxLanes = 3
    @Environment(\.pagePalette) private var page

    private var lead: QueueItem { downloads[0] }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let checked { V2SelectCheck(on: checked).padding(.top, 20) }
            PosterImage(url: TMDBImage.resized(lead.posterUrl, to: "w185"), size: CGSize(width: 44, height: 66))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(lead.title)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let time = V2QueueTime.clock(lead.grabbedAt) {
                        Text(time).font(.caption.monospacedDigit()).foregroundStyle(page?.inkMuted ?? Theme.mut)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
                    .padding(.top, 1)
                ForEach(downloads.prefix(maxLanes)) { item in
                    QueueLaneV2(model: QueueLaneModel(item, telemetry: telemetry[item.id]))
                        .padding(.top, 9)
                }
                if downloads.count > maxLanes {
                    Text("and \(downloads.count - maxLanes) more")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .padding(.top, 6)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// "S1 E7 · Immolation", else the movie's year and what triggered it.
    private var subtitle: String {
        var parts: [String] = []
        if let label = QueueCardText.subtitle(lead) { parts.append(label) } else { parts.append("Movie") }
        if downloads.count > 1, Set(downloads.map(\.tier)).count == downloads.count {
            parts.append(downloads.map(\.tier.badgeLetters).joined(separator: " and "))
        } else if downloads.count > 1 {
            parts.append("\(downloads.count) downloads")
        }
        if let trigger = lead.grabTrigger, let meta = ActProvenance.meta(trigger) { parts.append(meta.label) }
        return parts.joined(separator: " · ")
    }
}

/// One version's lane: badge, words, amount; the bar; the release line.
struct QueueLaneV2: View {
    let model: QueueLaneModel
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                EditionBadge(tier: model.tier, state: model.badge, showsCount: false)
                Text(model.label)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let amount = model.amount {
                    Text(amount)
                        .font(.system(size: 12.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .contentTransition(.numericText())
                }
            }
            bar.padding(.top, 6)
            if let release = model.release {
                Text(release)
                    .font(.system(size: 11.5))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
                    .padding(.top, 5)
            }
        }
    }

    @ViewBuilder private var bar: some View {
        switch model.bar {
        case .none: EmptyView()
        case .progress(let fraction): RailBarV2(progress: fraction)
        case .steps(let done, let total): V2StepTrack(done: done, total: total)
        }
    }
}

/// A decypharr job's stages as short segments: done in the label ink, the
/// running one in the accent, the rest the empty track (one ink, rule B4).
struct V2StepTrack: View {
    let done: Int
    let total: Int
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 4
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        let ink = inkOverride ?? .page
        HStack(spacing: 3) {
            ForEach(0..<max(1, total), id: \.self) { index in
                Capsule()
                    .fill(index < done ? ink.fill : (index == done ? ink.accent : ink.track))
                    .frame(height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The select-mode check: an empty ring, or filled in the accent (selection).
struct V2SelectCheck: View {
    let on: Bool

    var body: some View {
        ZStack {
            Circle().strokeBorder(Theme.txt.opacity(0.3), lineWidth: 2).opacity(on ? 0 : 1)
            Circle().fill(Theme.primary).opacity(on ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .opacity(on ? 1 : 0)
        }
        .frame(width: 24, height: 24)
        .accessibilityLabel(on ? "Selected" : "Not selected")
    }
}

/// The queue's clock times ("17:42").
enum V2QueueTime {
    static func clock(_ iso: String?) -> String? {
        guard let date = ServerTime.parse(iso) else { return nil }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
