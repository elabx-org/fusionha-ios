import SwiftUI
import FusionhaKit

// The Seasons tab's episode list (MobileEpisodeList, redesign `.ep`): plain
// rows inside the season card, split by inset hairlines, with one status chip
// per scoped version. A tap opens the episode sheet; the chevron peeks the per-version
// facts + actions inline.

struct EpisodeList: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let season: Season

    var body: some View {
        let oldest = store.oldestFirst.contains(season.seasonNumber)
        let episodes = season.episodes.sorted { oldest ? $0.episodeNumber < $1.episodeNumber : $0.episodeNumber > $1.episodeNumber }
        LazyVStack(spacing: 0) {
            ForEach(episodes) { episode in
                EpisodeCard(detail: detail, season: season, episode: episode,
                            separated: episode.id != episodes.first?.id)
            }
        }
        .padding(.bottom, 4)
    }
}

private struct EpisodeCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let season: Season
    let episode: Episode
    /// A hairline above the row (every row but the first).
    let separated: Bool
    @State private var expanded = false

    /// Where the hairline starts: past the bookmark, under the text.
    private static let separatorInset: CGFloat = 50

    private var code: String {
        EpisodeCode.episode(season: season.seasonNumber, episode: episode.episodeNumber, separator: "")
    }

    var body: some View {
        let editions = store.scopedEditions
        let failed = editions.contains { episode.file(for: $0.id)?.analysis == "failed" }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                monitorToggle
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(numberText)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .fixedSize()
                        .frame(minWidth: 26, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title ?? "TBA")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statusLine(editions, failed: failed)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { openSheet(.details) }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Episode details") { openSheet(.details) }
                Button { expanded.toggle() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse \(code)" : "Expand \(code)")
            }
            .padding(.leading, 4)
            .padding(.trailing, 2)
            .padding(.vertical, 6)
            .frame(minHeight: 44)

            if expanded {
                EpisodeBody(detail: detail, season: season, episode: episode, code: code)
                    .padding(.horizontal, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            if failed { Theme.miss.opacity(0.08) }
        }
        .overlay(alignment: .top) {
            if separated {
                Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, Self.separatorInset)
            }
        }
        .detailAnimation(.easeInOut(duration: 0.2), value: expanded)
    }

    /// The second line: the air date, then one status chip per scoped version.
    private func statusLine(_ editions: [DetailEdition], failed: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            AirTimeText(episode: episode)
            Spacer(minLength: 4)
            FlowRow(spacing: 6, lineSpacing: 4) {
                ForEach(editions) { edition in
                    EpisodeStatusChip(episode: episode, edition: edition)
                }
                if editions.contains(where: { episode.file(for: $0.id)?.unresolved == true }) || failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.stuck)
                }
                if isPaused(editions) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.stuck)
                        .detailPulse(low: 0.35, high: 1, period: 2.4)
                }
            }
            .layoutPriority(1)
        }
    }

    /// Per-episode monitor toggle: the season toolbar's bookmark (filled =
    /// monitored), its own tap target. A read-only visitor sees the same
    /// bookmark, not tappable.
    @ViewBuilder
    private var monitorToggle: some View {
        let on = store.episodeMonitored(episode)
        if model.me?.can("edit") ?? true {
            let label = "S\(season.seasonNumber)·E\(episode.episodeNumber)"
            Button {
                Task { await store.setEpisodeMonitored(episode, seasonNumber: season.seasonNumber, !on) }
            } label: {
                Image(systemName: on ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15))
                    .foregroundStyle(on ? Theme.txt : Theme.dim)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(DetailPressStyle())
            .accessibilityLabel(on ? "Stop monitoring \(label)" : "Monitor \(label)")
            .accessibilityAddTraits(on ? .isSelected : [])
        } else {
            Image(systemName: on ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15))
                .foregroundStyle(on ? Theme.txt : Theme.dim)
                .frame(width: 36, height: 44)
                .accessibilityLabel(on ? "Monitored" : "Not monitored")
        }
    }

    private func openSheet(_ tab: EpisodeSheetTab) {
        store.episodeSheet = EpisodeSheetTarget(episodeId: episode.id, seasonNumber: season.seasonNumber, tab: tab)
    }

    private var numberText: String {
        var text = "E\(episode.episodeNumber)"
        if detail.isAnime == true, let abs = episode.absoluteNumber { text += " · #\(abs)" }
        return text
    }

    private func isPaused(_ editions: [DetailEdition]) -> Bool {
        let now = DetailText.instant(store.pauses?.now) ?? Date()
        let ids = Set(editions.map(\.id))
        return (store.pauses?.episodes ?? []).contains { p in
            p.episodeId == episode.id && ids.contains(p.editionId ?? -1)
                && (DetailText.instant(p.cooldownUntil).map { $0 > now } ?? false)
        }
    }
}

/// AirTime: "Mar 22", today's time, "airing now", or "—".
private struct AirTimeText: View {
    let episode: Episode

    var body: some View {
        let now = Date()
        Group {
            if let instant = episode.airInstant {
                let hasTime = episode.airDatetime != nil
                if hasTime && instant <= now && now.timeIntervalSince(instant) < 90 * 60 {
                    Text("airing now").foregroundStyle(Theme.onair).detailPulse(low: 0.5, high: 1, period: 1.6)
                } else if hasTime && Calendar.current.isDateInToday(instant) {
                    Text(instant.formatted(date: .omitted, time: .shortened)).foregroundStyle(Theme.onair)
                } else {
                    Text(instant.formatted(.dateTime.month(.abbreviated).day()))
                }
            } else {
                Text("—")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.mut)
        .lineLimit(1)
        .fixedSize()
    }
}
