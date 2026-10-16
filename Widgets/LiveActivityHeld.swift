import SwiftUI
import WidgetKit

/// The held state on the Lock Screen (mock G2): overlapping posters with an
/// amber pause badge, the count, and Review all in the top-right corner; then
/// one line per title (title, version, episode count, the hold in a few words)
/// and "and N more". Kept compact: the Lock Screen gives a Live Activity about
/// 160pt, and the stale line still has to fit.
struct LiveActivityHeldView: View {
    let state: DownloadsActivityAttributes.ContentState

    private var lines: [DownloadsActivityAttributes.ContentState.Held] { Array(state.held.prefix(2)) }
    /// Held downloads not covered by the lines shown.
    private var more: Int { max(0, state.needYou - lines.reduce(0) { $0 + $1.count }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                LiveActivityPosterStack(ids: state.held.prefix(3).map(\.mediaItemId))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        LiveActivityHero(text: "\(state.needYou)", size: 38, color: Theme.miss)
                        Text("need you").font(.system(size: 16, weight: .bold))
                    }
                    Text("held for review").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                .padding(.top, 4)
                Spacer(minLength: 4)
                reviewButton
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(lines, id: \.mediaItemId) { line in
                    (Text(line.title).fontWeight(.semibold)
                     + Text(line.version.map { " \($0)" } ?? "").font(.system(size: 11, weight: .bold))
                        .foregroundColor(LiveActivityTone.version(line.version ?? ""))
                     + Text(line.count > 1 ? " ×\(line.count)" : "").foregroundColor(.white.opacity(0.7))
                     + Text("  \(line.reason)").foregroundColor(Theme.miss))
                        .font(.system(size: 13.5))
                        .lineLimit(1)
                }
                if more > 0 {
                    Text("and \(more) more").font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }

    @ViewBuilder
    private var reviewButton: some View {
        if let link = LiveActivityLinks.review(state.held.flatMap(\.downloadIds)) {
            Link(destination: link) {
                Label(state.needYou > 1 ? "Review all" : "Review", systemImage: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Theme.miss.opacity(0.25), in: Capsule())
                    .fixedSize()
            }
        }
    }
}

/// Up to three posters overlapping like a group of avatars (first on top,
/// each behind tilted a little more), with an amber pause badge.
struct LiveActivityPosterStack: View {
    let ids: [Int]

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(ids.indices.reversed()), id: \.self) { i in
                LiveActivityPoster(mediaItemId: ids[i], width: 38)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(.black.opacity(0.6), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
                    .rotationEffect(.degrees(Double(i) * 3), anchor: .bottomLeading)
                    .offset(x: CGFloat(i) * 28)
            }
        }
        .frame(width: 38 + CGFloat(max(0, ids.count - 1)) * 28 + 4, height: 60, alignment: .leading)
        .overlay(alignment: .bottomLeading) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black, Theme.miss)
                .offset(x: -5, y: 5)
        }
    }
}
