import SwiftUI
import FusionhaKit

// One season of the Seasons tab, drawn as one card (`detailCard`): the
// header ("Season 4  23 of 26 · 2 GB" and the ⋯ sheet), the progress bar,
// then its episode rows (DetailEpisodes) as plain rows inside the card.

struct SeasonCard: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let season: Season
    let isOpen: Bool
    let toggle: () -> Void

    private static let radius: CGFloat = 22

    var body: some View {
        let ids = store.scopedEditions.map(\.id)
        let c = season.completion(editionIds: ids)
        let paused = pausedCount(ids)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                SeasonHeader(season: season, done: c.done, total: c.total,
                             bytes: season.bytes(editionIds: ids), isOpen: isOpen, toggle: toggle)
                SeasonBar(total: c.total, done: c.done, downloading: c.downloading, attention: c.attention)
                    .padding(.trailing, 4)
                if paused > 0 { cooling(paused) }
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.top, 10)
            .padding(.bottom, isOpen ? 6 : 14)
            .background(season.seasonNumber == 0 ? Theme.miss.opacity(0.06) : .clear)

            if isOpen {
                EpisodeList(detail: detail, season: season)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
        .detailCard(radius: Self.radius)
        .padding(.bottom, 16)
        .detailAnimation(.timingCurve(0.52, 0.01, 0.16, 1, duration: 0.42), value: isOpen)
    }

    private func cooling(_ paused: Int) -> some View {
        Text("\(paused) cooling down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.stuck)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.stuck.opacity(0.12), in: Capsule())
            .detailPulse(low: 0.35, high: 1, period: 2.4)
            .accessibilityHint("Cooling down after failed downloads · a manual search runs now and ignores the cooldown")
    }

    private func pausedCount(_ ids: [Int]) -> Int {
        let now = DetailText.instant(store.pauses?.now) ?? Date()
        let episodeIds = Set(season.episodes.map(\.id))
        let paused = (store.pauses?.episodes ?? []).filter { p in
            guard let e = p.episodeId, episodeIds.contains(e), let ed = p.editionId, ids.contains(ed),
                  let until = DetailText.instant(p.cooldownUntil) else { return false }
            return until > now
        }
        return Set(paused.compactMap(\.episodeId)).count
    }
}

/// "⌄ Season 4  23 of 26 · 2 GB  ⋯": the title at 22 bold, the count and
/// size at 15 muted, then the glass ⋯ season sheet.
private struct SeasonHeader: View {
    @Environment(DetailStore.self) private var store
    let season: Season
    let done: Int
    let total: Int
    let bytes: Double
    let isOpen: Bool
    let toggle: () -> Void

    private var meta: String {
        let count = "\(done) of \(total)"
        return bytes > 0 ? "\(count) · \(DetailText.bytes(bytes))" : count
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.mut)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .detailAnimation(.easeInOut(duration: 0.2), value: isOpen)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(season.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                            .fixedSize()
                        Text(meta)
                            .font(.system(size: 15).monospacedDigit())
                            .foregroundStyle(Theme.mut)
                            .lineLimit(1)
                            .contentTransition(.numericText(value: Double(done)))
                            .detailAnimation(.easeOut(duration: 0.4), value: done)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(season.title), \(done) of \(total)")
            moreButton
        }
    }

    private var moreButton: some View {
        Button {
            store.seasonSheet = SeasonRef(number: season.seasonNumber)
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(Theme.txt)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .padding(.horizontal, -4).padding(.vertical, -4)
        }
        .buttonStyle(DetailPressStyle())
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("\(season.title) actions")
    }
}

/// The 6pt season bar: present (with a stuck-coloured attention tail) then a
/// striped downloading segment over a miss-tinted track.
private struct SeasonBar: View {
    let total: Int
    let done: Int
    let downloading: Int
    let attention: Int
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let doneW = total > 0 ? w * CGFloat(done) / CGFloat(total) : 0
            let dlW = total > 0 ? w * CGFloat(downloading) / CGFloat(total) : 0
            let attentionShare = done > 0 ? Double(attention) / Double(done) : 0
            HStack(spacing: 0) {
                // Done, then the share that needs attention, as solid segments.
                HStack(spacing: 0) {
                    Theme.done.frame(width: (shown ? doneW : 0) * (1 - attentionShare))
                    Theme.stuck.frame(width: (shown ? doneW : 0) * attentionShare)
                }
                .frame(width: shown ? doneW : 0)
                if downloading > 0 {
                    Theme.grab
                        .overlay(DetailStripes())
                        .frame(width: shown ? dlW : 0)
                }
                Spacer(minLength: 0)
            }
            .background(Theme.miss.mix(0.3, Theme.bg))
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .detailAnimation(DetailMotion.barFill, value: shown)
        .onAppear { shown = true }
    }
}
