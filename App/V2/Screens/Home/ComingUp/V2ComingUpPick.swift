import Foundation
import FusionhaKit

/// One "Coming up" card: the library title, the release or airing that
/// put it on the row, what it is ("Digital", "S2 E5") and when ("Fri",
/// "tonight"); `reason` joins them ("Digital · Fri").
struct V2ComingUpCard: Identifiable, Equatable {
    let item: MediaItem
    let at: Date
    let what: String
    let when: String
    var reason: String { "\(what) · \(when)" }
    var id: Int { item.id }

    static func == (a: V2ComingUpCard, b: V2ComingUpCard) -> Bool {
        a.item.id == b.item.id && a.at == b.at && a.reason == b.reason
    }
}

/// Picks the "Coming up" cards from the calendar feed (`GET /api/v1/calendar`,
/// the feed v1's Calendar and the idle queue read): library titles only,
/// one card per title (a series shows its next qualifying episode), the
/// kinds the menu has on, inside the window, soonest first.
enum V2ComingUpPick {
    static let limit = 12

    /// `titles`: the library titles the filters leave, by id.
    static func cards(_ entries: [CalendarEntry], titles: [Int: MediaItem], kinds: Set<V2ComingUpKind>,
                      days: Int, now: Date = Date(), calendar: Calendar = .current) -> [V2ComingUpCard] {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: days + 1, to: today) ?? now
        var best: [Int: (entry: CalendarEntry, kind: V2ComingUpKind, at: Date)] = [:]
        for entry in entries {
            guard titles[entry.itemId] != nil, let found = kind(of: entry),
                  kinds.contains(found) || (!entry.isMovie && kinds.contains(.nextEpisode)),
                  let at = IdleComingUp.airDate(entry, calendar: calendar) else { continue }
            // A timed airing counts until it starts; a date-only one all day.
            let timed = entry.airDatetime != nil
            guard (timed ? at >= now : at >= today), at < end else { continue }
            if let kept = best[entry.itemId], kept.at <= at { continue }
            best[entry.itemId] = (entry, found, at)
        }
        return best.values
            .sorted { $0.at != $1.at ? $0.at < $1.at : $0.entry.title < $1.entry.title }
            .prefix(limit)
            .compactMap { pick in
                guard let item = titles[pick.entry.itemId] else { return nil }
                let when = V2ComingUpWhen.words(pick.at, timed: pick.entry.airDatetime != nil,
                                                now: now, calendar: calendar)
                return V2ComingUpCard(item: item, at: pick.at, what: label(pick.entry, kind: pick.kind), when: when)
            }
    }

    /// The entry's kind: a movie by its release type; an episode is a series
    /// premiere (S1 E1), a season premiere (E1 of a later season) or a next
    /// episode (absolute-only anime by its number). Specials (season 0) and
    /// unknown release types stay out.
    static func kind(of entry: CalendarEntry) -> V2ComingUpKind? {
        if entry.isMovie {
            switch entry.movieReleaseType {
            case .digital?: return .digital
            case .physical?: return .physical
            case .theatrical?: return .cinemas
            case nil: return nil
            }
        }
        if entry.seasonNumber == 0 { return nil }
        // Anime that comes with absolute numbers only: #1 opens the series.
        guard let season = entry.seasonNumber else {
            return entry.absoluteNumber == 1 ? .seriesPremiere : .nextEpisode
        }
        guard entry.episodeNumber == 1 else { return .nextEpisode }
        return season == 1 ? .seriesPremiere : .seasonPremiere
    }

    /// The card's reason, before the day.
    static func label(_ entry: CalendarEntry, kind: V2ComingUpKind) -> String {
        switch kind {
        case .digital: return "Digital"
        case .physical: return "Blu-ray"
        case .cinemas: return "In cinemas"
        case .seriesPremiere: return "Series premiere"
        case .seasonPremiere: return "Season \(entry.seasonNumber ?? 0) premiere"
        case .nextEpisode:
            if let s = entry.seasonNumber, let e = entry.episodeNumber { return "S\(s) E\(e)" }
            if let abs = entry.absoluteNumber { return "#\(abs)" }
            return "Next episode"
        }
    }
}
