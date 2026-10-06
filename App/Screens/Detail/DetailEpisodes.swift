import SwiftUI
import FusionhaKit

// The Seasons tab's episode list (MobileEpisodeList): carded episode rows with
// one status chip per scoped version, and the expanded per-version facts + actions.

struct EpisodeList: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let season: Season

    var body: some View {
        let oldest = store.oldestFirst.contains(season.seasonNumber)
        let episodes = season.episodes.sorted { oldest ? $0.episodeNumber < $1.episodeNumber : $0.episodeNumber > $1.episodeNumber }
        LazyVStack(spacing: 8) {
            ForEach(episodes) { episode in
                EpisodeCard(detail: detail, season: season, episode: episode)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
    }
}

private struct EpisodeCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let season: Season
    let episode: Episode
    @State private var expanded = false

    private var code: String {
        "S\(String(format: "%02d", season.seasonNumber))E\(String(format: "%02d", episode.episodeNumber))"
    }

    var body: some View {
        let editions = store.scopedEditions
        let failed = editions.contains { episode.file(for: $0.id)?.analysis == "failed" }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                monitorToggle
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(numberText)
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.mut)
                            .fixedSize()
                        Text(episode.title ?? "TBA")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
                .contentShape(Rectangle())
                .onTapGesture { expanded.toggle() }
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
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .padding(.vertical, 6)
            .frame(minHeight: 44)

            if expanded {
                EpisodeBody(detail: detail, season: season, episode: episode, code: code)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            if failed {
                LinearGradient(colors: [Theme.miss.mix(0.1, Theme.card), Theme.card], startPoint: .leading, endPoint: .trailing)
            } else {
                Theme.card
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
        .padding(.horizontal, 8)
        .detailAnimation(.easeInOut(duration: 0.2), value: expanded)
    }

    /// Per-episode monitor toggle: the season toolbar's bookmark (filled =
    /// monitored), its own tap target. A read-only visitor sees the dot.
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
                    .foregroundStyle(on ? Theme.cyan : Theme.dim)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(DetailPressStyle())
            .accessibilityLabel(on ? "Stop monitoring \(label)" : "Monitor \(label)")
            .accessibilityAddTraits(on ? .isSelected : [])
        } else {
            Circle()
                .fill(on ? Theme.cyan : .clear)
                .overlay(Circle().strokeBorder(Theme.mut, lineWidth: 1.5))
                .frame(width: 9, height: 9)
                .accessibilityLabel(on ? "Monitored" : "Not monitored")
        }
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
        .font(.system(size: 12))
        .foregroundStyle(Theme.mut)
        .lineLimit(1)
        .fixedSize()
    }
}

/// The expanded body: one facts block per scoped edition, then the actions.
private struct EpisodeBody: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let season: Season
    let episode: Episode
    let code: String

    var body: some View {
        let editions = store.scopedEditions
        VStack(alignment: .leading, spacing: 12) {
            ForEach(editions) { edition in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(edition.label).font(.system(size: 11, weight: .heavy)).foregroundStyle(DetailTokens.tier(edition.tier))
                        Spacer(minLength: 0)
                        EpisodeStatusChip(episode: episode, edition: edition)
                    }
                    if let file = episode.file(for: edition.id) {
                        facts(file)
                    } else {
                        Text("No file for this version.").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    }
                }
                .padding(10)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
            }
            if model.me?.can("search") ?? true {
                HStack(spacing: 8) {
                    SearchActionButton(label: code, editionId: store.scopeEditionId, episodeId: episode.id,
                                       size: 44, glyph: 16, bordered: true)
                    interactive(editions)
                }
            }
        }
        .padding(12)
    }

    private func facts(_ file: MovieFile) -> some View {
        let probe = file.mediaInfo?.probe
        var rows: [(String, String)] = [("Quality", DetailText.quality(file.quality)), ("Size", DetailText.bytes(file.size))]
        if let v = DetailMediaFacts.audio(probe) { rows.append(("Audio", v)) }
        if let v = DetailMediaFacts.codec(probe) { rows.append(("Codec", v)) }
        if let v = DetailMediaFacts.range(probe) { rows.append(("Range", v)) }
        if let v = file.releaseGroup, !v.isEmpty { rows.append(("Group", v)) }
        if let v = file.cfScore { rows.append(("CF", v >= 0 ? "+\(v)" : "\(v)")) }
        if let v = file.languages, !v.isEmpty { rows.append(("Languages", v.joined(separator: ", "))) }
        if let v = file.releaseType, !v.isEmpty, v != "unknown" { rows.append(("Release Type", v)) }
        return LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
                         alignment: .leading, spacing: 10) {
            ForEach(rows.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 2) {
                    Text(rows[i].0.uppercased()).font(.system(size: 10, weight: .bold)).tracking(0.5).foregroundStyle(Theme.dim)
                    Text(rows[i].1)
                        .font(.system(size: 12.5, design: rows[i].0 == "Size" ? Font.Design.monospaced : Font.Design.default))
                        .foregroundStyle(rows[i].0 == "Size" ? Theme.mut : Theme.txt)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// ManualSearchTrigger: direct with one version, else "Search which version?".
    @ViewBuilder
    private func interactive(_ editions: [DetailEdition]) -> some View {
        let all = detail.orderedEditions
        if all.count == 1, let only = all.first {
            DetailSquareAction(systemImage: "person", label: "Interactive search") {
                store.interactive = InteractiveTarget(editionIds: [only.id], episodeId: episode.id,
                                                      subtitle: "S\(season.seasonNumber)·E\(episode.episodeNumber)")
            }
        } else {
            Menu {
                Section("Search which version?") {
                    ForEach(all) { edition in
                        Button {
                            store.interactive = InteractiveTarget(editionIds: [edition.id], episodeId: episode.id,
                                                                  subtitle: "S\(season.seasonNumber)·E\(episode.episodeNumber)")
                        } label: {
                            Text(edition.label)
                            Text(episode.file(for: edition.id) == nil
                                 ? "missing — most likely what you want · 1 query"
                                 : "has a file · re-search for an upgrade · 1 query")
                        }
                    }
                    Button {
                        store.interactive = InteractiveTarget(editionIds: all.map(\.id), episodeId: episode.id,
                                                              subtitle: "S\(season.seasonNumber)·E\(episode.episodeNumber)")
                    } label: {
                        Text("All versions")
                        Text("search every version · tiers × versions · \(all.count) queries")
                    }
                }
            } label: {
                Image(systemName: "person")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 44, height: 44)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
            }
            .accessibilityLabel("Interactive search")
        }
    }
}
