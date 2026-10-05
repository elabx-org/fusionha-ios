import SwiftUI
import FusionhaKit

// The Seasons tab (SeasonsAccordion + MobileEpisodeList): season cards with a
// striped progress bar and a ⋮ sheet, carded episode rows with one status chip
// per scoped version, and the expanded per-version facts + actions.

struct SeasonsTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let openWeb: () -> Void
    @State private var open: Set<Int>?

    /// The running `tree` step's source while the season list is still empty.
    private var waitingSource: String? {
        guard let setup = model.setupProgress.activeSetup(for: detail.id),
              let tree = setup.steps.first(where: { $0.key == "tree" }),
              tree.status == .running else { return nil }
        return tree.source ?? "the provider"
    }

    var body: some View {
        let seasons = detail.seasonsNewestFirst
        let openSet = open ?? Set(seasons.prefix(1).map(\.seasonNumber))
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("SEASONS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.72)
                    .foregroundStyle(Theme.mut)
                Spacer(minLength: 4)
                if let e = store.enrichment, let pending = e.pendingFiles, pending > 0 {
                    AnalysisPill(status: e) {
                        model.tab = .activity
                        model.presentedItem = nil
                    }
                }
                if model.me?.can("edit") ?? true {
                    Button {
                        Task { await store.checkNumbering(openWeb: openWeb) }
                    } label: {
                        Image(systemName: "list.number")
                            .foregroundStyle(detail.numberingMismatch == true ? Theme.miss : Theme.mut)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(DetailPressStyle())
                    .accessibilityLabel("Check episode numbering")
                }
                if seasons.count > 1 {
                    let allOpen = openSet.count == seasons.count
                    Button {
                        open = allOpen ? Set<Int>() : Set(seasons.map(\.seasonNumber))
                    } label: {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(allOpen ? 90 : 0))
                            .foregroundStyle(Theme.mut)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(DetailPressStyle())
                    .accessibilityLabel(allOpen ? "Collapse all seasons" : "Expand all seasons")
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 14)

            if detail.numberingMismatch == true {
                Button(action: openWeb) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(detail.episodeNumberingSource == "tvmaze"
                             ? "Episode numbering may be off vs TVmaze — Review"
                             : "TheTVDB renumbered this show — Review")
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.miss)
                    .padding(12)
                    .background(Theme.miss.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.miss.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }

            if seasons.isEmpty {
                if let source = waitingSource {
                    SeasonsWaiting(source: source)
                } else {
                    EmptyBox(message: "No seasons yet for this title.")
                }
            }
            ForEach(seasons) { season in
                SeasonCard(detail: detail, season: season, isOpen: openSet.contains(season.seasonNumber)) {
                    var next = openSet
                    if next.contains(season.seasonNumber) { next.remove(season.seasonNumber) } else { next.insert(season.seasonNumber) }
                    open = next
                }
            }
        }
    }
}

/// While the setup's `tree` step is still building the season list (TVDB-only /
/// Hybrid): a skeleton + "Waiting for seasons from TVDB…" (ItemDetail
/// `seasonsWaiting`, SeasonsAccordion `.seasonsWaiting`).
private struct SeasonsWaiting: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach([0.7, 0.9, 0.55], id: \.self) { width in
                    GeometryReader { geo in
                        SkeletonBar(height: 12, radius: 6).frame(width: geo.size.width * width)
                    }
                    .frame(height: 12)
                }
            }
            .accessibilityHidden(true)
            Text("Waiting for seasons from \(source)…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radius))
    }
}

/// "Analysing N files · P%" (AnalysisProgressPill).
private struct AnalysisPill: View {
    let status: EnrichmentStatus
    let action: () -> Void

    var body: some View {
        let pending = status.pendingFiles ?? 0
        let total = max(status.totalFiles ?? 0, 1)
        let pct = Int((Double(status.enrichedFiles ?? 0) / Double(total) * 100).rounded())
        Button(action: action) {
            HStack(spacing: 6) {
                DetailSpinner(size: 12, color: Theme.indigo, period: 0.9)
                Text("Analysing \(pending) file\(pending == 1 ? "" : "s") · \(pct)%")
                    .lineLimit(1)
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Theme.indigo)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Theme.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.indigo.opacity(0.4)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Season card

private struct SeasonCard: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let season: Season
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        let editions = store.scopedEditions
        let ids = editions.map(\.id)
        let c = season.completion(editionIds: ids)
        let paused = pausedCount(ids)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Button(action: toggle) {
                        HStack(spacing: 10) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.mut)
                                .rotationEffect(.degrees(isOpen ? 90 : 0))
                                .detailAnimation(.easeInOut(duration: 0.2), value: isOpen)
                            Text(season.title)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(Theme.txt)
                                .lineLimit(1)
                                .fixedSize()
                            Text("\(c.done)/\(c.total)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.mut)
                                .contentTransition(.numericText(value: Double(c.done)))
                                .detailAnimation(.easeOut(duration: 0.4), value: c.done)
                            Spacer(minLength: 4)
                            Text(DetailText.bytes(season.bytes(editionIds: ids)))
                                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(season.title), \(c.done) of \(c.total)")
                    Button {
                        store.seasonSheet = SeasonRef(number: season.seasonNumber)
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .foregroundStyle(Theme.mut)
                            .frame(width: 44, height: 44)
                            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))
                    }
                    .buttonStyle(DetailPressStyle())
                    .accessibilityLabel("\(season.title) actions")
                }
                SeasonBar(total: c.total, done: c.done, downloading: c.downloading, attention: c.attention)
                if paused > 0 {
                    Text("\(paused) cooling down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.stuck)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.stuck.opacity(0.12), in: Capsule())
                        .detailPulse(low: 0.35, high: 1, period: 2.4)
                        .accessibilityHint("Cooling down after failed downloads · a manual search runs now and ignores the cooldown")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(season.seasonNumber == 0 ? Theme.miss.opacity(0.06) : .clear)

            if isOpen {
                Rectangle().fill(Theme.line).frame(height: 1)
                EpisodeList(detail: detail, season: season)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.line))
        .padding(.bottom, 12)
        .detailAnimation(.timingCurve(0.52, 0.01, 0.16, 1, duration: 0.42), value: isOpen)
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
                LinearGradient(stops: [
                    .init(color: Theme.done, location: 0),
                    .init(color: Theme.done, location: max(0, 1 - attentionShare)),
                    .init(color: Theme.stuck, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
                .frame(width: shown ? doneW : 0)
                if downloading > 0 {
                    Theme.grab
                        .overlay(DetailStripes())
                        .frame(width: shown ? dlW : 0)
                }
                Spacer(minLength: 0)
            }
            .background(Theme.miss.mix(0.3, Color(white: 0.08)))
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .detailAnimation(DetailMotion.barFill, value: shown)
        .onAppear { shown = true }
    }
}

// MARK: - Episodes

private struct EpisodeList: View {
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

// MARK: - Episode status chip

/// EpisodeStatus: the per-edition chip on an episode card.
struct EpisodeStatusChip: View {
    let episode: Episode
    let edition: DetailEdition

    var body: some View {
        let kind = episode.status(editionId: edition.id)
        let file = episode.file(for: edition.id)
        switch kind {
        case .owned:
            DetailQualityChip(quality: file?.quality, tier: edition.tier)
        case .attention:
            DetailQualityChip(quality: file?.quality, tier: edition.tier)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.miss.opacity(0.7), lineWidth: 1.5))
                .overlay(alignment: .topTrailing) { marker("!", Theme.miss) }
        case .upgrading:
            HStack(spacing: 4) {
                DetailQualityChip(quality: file?.quality, tier: edition.tier)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.edition.opacity(0.65), lineWidth: 1.5))
                Text("↑").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.edition)
                if let target = episode.download(for: edition.id)?.releaseQuality {
                    Text(DetailText.quality(target)).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Theme.cyan)
                }
            }
        case .downloading:
            DownloadPill(download: episode.download(for: edition.id))
        case .stuck:
            Text("⚠ STUCK")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.stuck)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.stuck.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.stuck.opacity(0.55), lineWidth: 1.5))
        case .missing:
            Text("missing")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.danger.mix(0.85, .white))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.danger.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
        case .soon:
            HStack(spacing: 3) {
                Image(systemName: "clock").font(.system(size: 10))
                Text("soon")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.mut)
        }
    }

    private func marker(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(Theme.bg)
            .frame(width: 11, height: 11)
            .background(color, in: Circle())
            .offset(x: 4, y: -4)
    }
}

/// The cyan "DOWNLOADING" pill; tapping it shows the release, its client and
/// indexer and the progress, with a jump to Activity › Queue.
private struct DownloadPill: View {
    @Environment(AppModel.self) private var model
    let download: EpisodeDownload?
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: 5) {
                DetailSpinner(size: 10, color: Theme.grab, period: 0.9)
                Text("DOWNLOADING")
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(Theme.grab.mix(0.88, .white))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.grab.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.grab.opacity(0.55), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 10) {
                Text(download?.releaseTitle ?? "Downloading")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach([download?.client, download?.indexer].compactMap { $0 }, id: \.self) { chip in
                        Text(chip)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                }
                if let progress = download?.progress {
                    HStack(spacing: 8) {
                        DetailCoverageBar(total: 100, owned: Int(progress), color: Theme.grab, height: 5)
                        Text("\(Int(progress))%").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.grab)
                    }
                }
                Button("Open in Activity") {
                    showing = false
                    model.tab = .activity
                    model.presentedItem = nil
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.cyan)
            }
            .padding(14)
            .frame(width: 280)
            .presentationCompactAdaptation(.popover)
            .presentationBackground(Theme.panel2)
        }
        .accessibilityLabel("Downloading")
    }
}

// MARK: - Season ⋮ sheet

struct SeasonActionsSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail
    let season: Season

    var body: some View {
        let n = season.seasonNumber
        let editionId = store.scopeEditionId
        let label = store.scopeEditionId == nil ? season.title : "\(season.title) · \(store.actsOnLabel)"
        let monitored = store.seasonMonitored(season)
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(season.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .padding(.bottom, 8)

                if model.me?.can("search") ?? true {
                    group("Search")
                    row("magnifyingglass", "Search season", sub: "One decision — prefers a season pack") {
                        dismiss()
                        Task { await store.search(label: label, editionId: editionId, season: n) }
                    }
                    row("text.magnifyingglass", "Search missing episodes",
                        sub: "The gaps only — one at a time, ~\(store.seasonInterval)s apart") {
                        dismiss()
                        Task { await store.gradualSearch(label: label, season: n, editionId: editionId, missingOnly: true) }
                    }
                    row("list.bullet.indent", "Search each episode", sub: "One at a time, ~\(store.seasonInterval)s apart") {
                        dismiss()
                        Task { await store.gradualSearch(label: label, season: n, editionId: editionId, missingOnly: false) }
                    }
                }

                group("State")
                if model.me?.can("edit") ?? true {
                    row(monitored ? "bookmark.fill" : "bookmark", "Monitored", value: monitored ? "On" : "Off") {
                        Task { await store.setSeasonMonitored(n, !monitored) }
                    }
                    row("arrow.clockwise", "Refresh & scan") {
                        dismiss()
                        Task { await store.refreshSeason(n) }
                    }
                }
                let oldest = store.oldestFirst.contains(n)
                row("arrow.up.arrow.down", "Sort", value: oldest ? "Oldest" : "Newest") {
                    if oldest { store.oldestFirst.remove(n) } else { store.oldestFirst.insert(n) }
                }

                group("View")
                row("clock.arrow.circlepath", "Season history") {
                    store.tab = .history
                    dismiss()
                }
            }
            .padding(20)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }

    private func group(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Theme.mut)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    private func row(_ icon: String, _ title: String, sub: String? = nil, value: String? = nil,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.txt)
                    .frame(width: 34, height: 34)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let sub { Text(sub).font(.system(size: 12)).foregroundStyle(Theme.mut) }
                }
                Spacer(minLength: 0)
                if let value {
                    Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.cyan)
                        .contentTransition(.opacity)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
