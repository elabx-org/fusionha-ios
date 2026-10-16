import SwiftUI
import WidgetKit

/// The held state on the Lock Screen (mock G2): overlapping posters, the count, and Review all in the top-right corner; then
/// one line per title (title, version, episode count, the hold in a few words)
/// and "and N more". Kept compact: the Lock Screen gives a Live Activity about
/// 160pt, and the stale line still has to fit.
struct LiveActivityHeldView: View {
    let state: DownloadsActivityAttributes.ContentState

    private var lines: [DownloadsActivityAttributes.ContentState.Held] { Array(state.held.prefix(2)) }
    /// Held downloads not covered by the lines shown.
    private var more: Int { max(0, state.needYou - lines.reduce(0) { $0 + $1.count }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                LiveActivityPosterStack(ids: state.held.prefix(3).map(\.mediaItemId))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        LiveActivityHero(text: "\(state.needYou)", size: 34, color: Theme.miss)
                        Text("need you").font(.system(size: 16, weight: .semibold))
                    }
                    Text("held for review").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
                Spacer(minLength: 4)
                reviewButton
            }
            VStack(alignment: .leading, spacing: 5) {
                ForEach(lines, id: \.mediaItemId) { HeldLine(line: $0) }
                if more > 0 {
                    Text("and \(more) more").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    @ViewBuilder
    private var reviewButton: some View {
        if let link = LiveActivityLinks.review(state.held.flatMap(\.downloadIds)) {
            Link(destination: link) {
                Text(state.needYou > 1 ? "Review all" : "Review")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, 13)
                    .frame(height: 28)
                    .background(Theme.miss, in: Capsule())
                    .fixedSize()
            }
        }
    }
}

/// One held title: the title, its tier as a small chip, the count, and the
/// hold in a few words (quiet, so amber stays on the count and the button).
private struct HeldLine: View {
    let line: DownloadsActivityAttributes.ContentState.Held

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(line.title).font(.system(size: 14, weight: .semibold)).lineLimit(1).layoutPriority(1)
            if let version = line.version.map(LiveActivityTone.shortVersion), !version.isEmpty {
                Text(version)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(LiveActivityTone.version(version))
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(LiveActivityTone.version(version).opacity(0.18), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .fixedSize()
            }
            if line.count > 1 {
                Text("×\(line.count)").font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6)).fixedSize()
            }
            Text(line.reason).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
        }
    }
}

/// Up to three posters overlapping like a group of avatars, first on top,
/// each cut out from the one behind by a dark ring.
struct LiveActivityPosterStack: View {
    let ids: [Int]
    private let width: CGFloat = 34
    private let step: CGFloat = 20

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(ids.indices.reversed()), id: \.self) { i in
                LiveActivityPoster(mediaItemId: ids[i], width: width, ring: i > 0 || ids.count > 1)
                    .opacity(i == 0 ? 1 : 0.9)
                    .offset(x: CGFloat(i) * step)
            }
        }
        .frame(width: width + CGFloat(max(0, ids.count - 1)) * step, height: width * 1.5, alignment: .leading)
    }
}
