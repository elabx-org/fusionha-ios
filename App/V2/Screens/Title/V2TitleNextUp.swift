import SwiftUI
import FusionhaKit

/// A series' next job (mock kit `nextUp`): the latest aired episode still
/// missing in a monitored version (within two weeks), else the next one to
/// air. Its per-version states come from v1's episode status.
struct V2TitleNextUp {
    let season: Int
    let episode: Episode
    let aired: Bool
    let states: [(tier: QualityTier, state: EditionBadgeState)]
    /// The episode after it that has not aired yet.
    let then: Episode?

    var code: String { "E\(episode.episodeNumber)" }
    var title: String { [code, episode.title].compactMap { $0 }.joined(separator: " · ") }

    @MainActor
    init?(detail: ItemDetail, store: DetailStore, now: Date = Date()) {
        guard detail.isSeries else { return nil }
        let editions = detail.orderedEditions.filter { store.editionMonitored($0) }
        guard !editions.isEmpty else { return nil }
        let episodes: [(Int, Episode)] = detail.seasonsAscending
            .filter { $0.seasonNumber > 0 && store.seasonMonitored($0) }
            .flatMap { season in season.episodes.map { (season.seasonNumber, $0) } }
            .filter { store.episodeMonitored($0.1) }
        let gap: Set<EpisodeStatusKind> = [.missing, .downloading, .stuck]
        let recent = now.addingTimeInterval(-14 * 86_400)
        let missing = episodes.last { pair in
            guard pair.1.hasAired(now: now), let air = pair.1.airInstant, air >= recent else { return false }
            return editions.contains { gap.contains(pair.1.status(editionId: $0.id, now: now)) }
        }
        let upcomingIndex = episodes.firstIndex { !$0.1.hasAired(now: now) && $0.1.airInstant != nil }
        guard let pick = missing ?? upcomingIndex.map({ episodes[$0] }) else { return nil }
        season = pick.0
        episode = pick.1
        aired = pick.1.hasAired(now: now)
        states = editions.map { (tier: $0.tier, state: Self.state(pick.1, edition: $0, now: now)) }
        let after = episodes.firstIndex { $0.1.id == pick.1.id }.map { $0 + 1 } ?? episodes.count
        then = episodes[min(after, episodes.count)...].first { !$0.1.hasAired(now: now) && $0.1.airInstant != nil }?.1
    }

    static func state(_ episode: Episode, edition: DetailEdition, now: Date) -> EditionBadgeState {
        switch episode.status(editionId: edition.id, now: now) {
        case .owned: return .onDisk
        case .attention, .stuck: return .held
        case .upgrading: return .downloading(progress: nil)
        case .downloading: return .downloading(progress: episode.download(for: edition.id)?.progress.map { $0 / 100 })
        case .missing, .soon: return .missing
        }
    }

    /// "Aired today, 05:00" / "Airs Tue 10 Nov, 05:00".
    static func when(_ episode: Episode, aired: Bool, now: Date = Date()) -> String? {
        guard let date = episode.airInstant else { return nil }
        let time = date.formatted(.dateTime.hour().minute())
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(date) {
            day = "today"
        } else if calendar.isDateInYesterday(date) {
            day = "yesterday"
        } else if calendar.isDateInTomorrow(date) {
            day = "tomorrow"
        } else {
            day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        return "\(aired ? "Aired" : "Airs") \(day), \(time)"
    }
}

/// The Next up card: the series art until episode stills arrive, the
/// episode, when it aired or airs, its versions' badges, and an automatic
/// search for it. Tapping the card opens the episode.
struct V2TitleNextUpCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let next: V2TitleNextUp
    var stillWidth: CGFloat = 112

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next up")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ink)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                Button { open() } label: { card }
                    .buttonStyle(PressScaleStyle(scale: 0.98))
                Button { search() } label: {
                    V2SearchLabel(title: "Search \(next.code)", activity: activity, iconOnly: true)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(activity?.isSearching == true)
            }
            .padding(10)
            .background { ModuleSurface(radius: 20) }
            if let then = next.then, let when = V2TitleNextUp.when(then, aired: false) {
                Label("Then \(["E\(then.episodeNumber)", then.title].compactMap { $0 }.joined(separator: " ")) · \(when.replacingOccurrences(of: "Airs ", with: ""))",
                      systemImage: "clock")
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var card: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(detail.backdropUrl ?? detail.posterUrl, to: "w300"))
                .frame(width: stillWidth, height: (stillWidth * 9 / 16).rounded())
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(next.title)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                if let when = V2TitleNextUp.when(next.episode, aired: next.aired) {
                    Text(when).font(.system(size: 12.5)).foregroundStyle(muted).lineLimit(1)
                }
                HStack(spacing: 5) {
                    if next.aired, next.states.contains(where: { $0.state == .missing }) {
                        Text("Missing in").font(.system(size: 12, weight: .semibold)).foregroundStyle(muted)
                    }
                    ForEach(next.states.indices, id: \.self) { i in
                        EditionBadge(tier: next.states[i].tier, state: next.states[i].state)
                    }
                    if let activity { V2SearchStatusLine(activity: activity).padding(.leading, 4) }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the episode")
    }

    private func open() {
        store.episodeSheet = EpisodeSheetTarget(episodeId: next.episode.id, seasonNumber: next.season)
    }

    private var activity: SearchActivity? { store.activity(.episode(next.episode.id)) }

    private func search() {
        let code = EpisodeCode.episode(season: next.season, episode: next.episode.episodeNumber)
        store.v2Search(.episode(next.episode.id), label: "\(detail.title) \(code)", episodeId: next.episode.id)
    }
}
