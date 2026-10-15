import SwiftUI
import WidgetKit

/// The held state on the Lock Screen: a fan of the held titles' posters with
/// an amber pause badge, beside the count and one line per title (title,
/// version, why it stopped), then Review in Manual Import. Kept compact: the
/// Lock Screen gives a Live Activity about 160pt.
struct LiveActivityHeldView: View {
    let state: DownloadsActivityAttributes.ContentState

    private var lines: [DownloadsActivityAttributes.ContentState.Held] { Array(state.held.prefix(2)) }
    /// Held downloads not covered by the lines shown.
    private var more: Int { max(0, state.needYou - lines.reduce(0) { $0 + $1.count }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                LiveActivityPosterFan(ids: state.held.prefix(3).map(\.mediaItemId))
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(state.needYou)").font(.system(size: 26, weight: .heavy).monospacedDigit())
                            .foregroundStyle(Theme.miss)
                        Text("need you").font(.system(size: 16, weight: .bold))
                        Spacer(minLength: 4)
                        Text("nothing downloading").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    }
                    ForEach(lines, id: \.mediaItemId) { line in
                        (Text(line.title).fontWeight(.semibold)
                         + Text(line.count > 1 ? " ×\(line.count)" : "").foregroundColor(.white.opacity(0.7))
                         + Text("  \(line.reason)").foregroundColor(Theme.miss.opacity(0.9)))
                            .font(.system(size: 13))
                            .lineLimit(1)
                    }
                    if more > 0 {
                        Text("and \(more) more").font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            if let link = LiveActivityLinks.review(state.held.flatMap(\.downloadIds)) {
                Link(destination: link) {
                    Label(state.needYou > 1 ? "Review all in Manual Import" : "Review in Manual Import",
                          systemImage: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Theme.miss.opacity(0.25), in: Capsule())
                }
            }
        }
    }
}

/// Up to three posters fanned like a hand of cards (first on top), with an
/// amber pause badge on the front one.
struct LiveActivityPosterFan: View {
    let ids: [Int]

    private func angle(_ i: Int) -> Double {
        switch ids.count {
        case 3: return [0, -11, 11][i]
        case 2: return [5, -7][i]
        default: return 0
        }
    }

    private func shift(_ i: Int) -> CGFloat {
        switch ids.count {
        case 3: return [0, -15, 15][i]
        case 2: return [6, -8][i]
        default: return 0
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(ids.indices.reversed()), id: \.self) { i in
                LiveActivityPoster(mediaItemId: ids[i], width: 44)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .rotationEffect(.degrees(angle(i)), anchor: .bottom)
                    .offset(x: shift(i))
                    .brightness(i == 0 ? 0 : -0.12)
            }
        }
        .frame(width: ids.count > 1 ? 82 : 48, height: 72)
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black, Theme.miss)
                .offset(x: 2, y: 4)
        }
    }
}
