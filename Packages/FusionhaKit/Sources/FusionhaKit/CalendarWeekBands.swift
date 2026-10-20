import Foundation

// The desktop Week's timeline (web `WeekView` layout `timeline`,
// `calendar-format.ts` BANDS / entryBand / nowBand): a time gutter and seven
// day columns cut into four bands. The day is still the entry's local air day;
// the band only picks the row within it.

/// The desktop Week layout (setting `calendar_week_layout`). Phones and
/// tablets always stack; this only chooses the desktop (1000+) variant.
public enum WeekLayout: String, CaseIterable, Sendable {
    case timeline, stacked

    /// `resolveWeekLayout`: the stored layout, else the shipped `timeline`.
    public static func resolve(_ value: String?) -> WeekLayout {
        value == WeekLayout.stacked.rawValue ? .stacked : .timeline
    }
}

/// One of the Week's four time bands, top to bottom.
public enum CalendarBand: String, CaseIterable, Sendable, Hashable {
    case early, day, prime, late

    public var label: String {
        switch self {
        case .early: return "Early"
        case .day: return "Day"
        case .prime: return "Prime"
        case .late: return "Late"
        }
    }

    /// The gutter's time label (the band's opening hour).
    public var timeLabel: String {
        switch self {
        case .early: return "12a"
        case .day: return "6a"
        case .prime: return "5p"
        case .late: return "9p"
        }
    }

    /// The band row's minimum height (the web's fixed min-heights, in points).
    public var minHeight: Double {
        switch self {
        case .early: return 214
        case .day: return 150
        case .prime, .late: return 92
        }
    }

    /// The band a local hour falls in: <6 Early, <17 Day, <21 Prime, else Late.
    public static func of(hour: Double) -> CalendarBand {
        hour < 6 ? .early : hour < 17 ? .day : hour < 21 ? .prime : .late
    }

    /// `entryBand`: the local hour of the precise air instant; a date-only
    /// entry (a movie, an untimed episode) sits in Day.
    public static func of(_ entry: CalendarEntry, _ calendar: Calendar = .current) -> CalendarBand {
        guard let instant = entry.airDatetimeInstant else { return .day }
        return of(hour: Double(calendar.component(.hour, from: instant)))
    }

    /// `nowBand`: the band the wall clock is in.
    public static func now(_ date: Date, _ calendar: Calendar = .current) -> CalendarBand {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return of(hour: Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60)
    }
}

/// One card in a band cell: a season drop or a single episode / release.
public enum WeekBandCard: Sendable, Hashable {
    case season(SeasonGroup)
    case single(CalendarEntry)

    public var entry: CalendarEntry {
        switch self {
        case .season(let group): return group.item
        case .single(let entry): return entry
        }
    }
}

/// One day-and-band cell of the timeline.
public struct WeekBandCell: Sendable, Hashable {
    public let cards: [WeekBandCard]
    /// Where the now line goes (between aired and upcoming cards), only in
    /// today's cell of the band the clock is in.
    public let nowIndex: Int?

    /// The cell's cards: season drops first, then singles, in their day order.
    /// In the now cell they are re-ordered aired first, then by air time, and
    /// the now line splits the two (the web's in-flow `wnowRow`).
    public static func make(seasons: [SeasonGroup], singles: [CalendarEntry], band: CalendarBand,
                            isNowCell: Bool, now: Date, _ calendar: Calendar = .current) -> WeekBandCell {
        var cards = seasons.filter { CalendarBand.of($0.item, calendar) == band }.map(WeekBandCard.season)
            + singles.filter { CalendarBand.of($0, calendar) == band }.map(WeekBandCard.single)
        guard isNowCell else { return WeekBandCell(cards: cards, nowIndex: nil) }
        let time = { (card: WeekBandCard) in card.entry.airInstant ?? .distantFuture }
        cards.sort { a, b in
            let airedA = a.entry.hasAired(now: now), airedB = b.entry.hasAired(now: now)
            return airedA == airedB ? time(a) < time(b) : airedA
        }
        return WeekBandCell(cards: cards, nowIndex: cards.filter { $0.entry.hasAired(now: now) }.count)
    }
}
