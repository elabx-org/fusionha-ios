import Foundation

// The Calendar screen's settings, enums and pure date/status helpers, ported from
// the web's `routes/calendar-format.ts`, `components/detail/air-format.ts` and the
// helpers at the top of `routes/Calendar.tsx`. Days are keyed by local ISO strings
// (`yyyy-MM-dd`) exactly like the web, so grouping and "today" match it.

// MARK: - Settings  (GET/PUT /api/v1/settings, the subset the app reads)

public struct AppSettings: Decodable, Sendable, Equatable {
    public let firstDayOfWeek: Int?
    public let calendarDefaultView: String?
    public let calendarWeekCardStyle: String?
    /// `calendar_week_layout` (`AppSettingsRead`, `timeline` | `stacked`), read
    /// only; optional so a server without it still decodes. See `weekLayout`.
    public let calendarWeekLayout: String?
    public let voicePlayful: Bool?
    public let animationsEnabled: Bool?

    public init(firstDayOfWeek: Int? = nil, calendarDefaultView: String? = nil, calendarWeekCardStyle: String? = nil,
                voicePlayful: Bool? = nil, animationsEnabled: Bool? = nil, calendarWeekLayout: String? = nil) {
        self.firstDayOfWeek = firstDayOfWeek
        self.calendarDefaultView = calendarDefaultView
        self.calendarWeekCardStyle = calendarWeekCardStyle
        self.calendarWeekLayout = calendarWeekLayout
        self.voicePlayful = voicePlayful
        self.animationsEnabled = animationsEnabled
    }

    /// The desktop Week layout; `timeline` when unset or unknown.
    public var weekLayout: WeekLayout { WeekLayout.resolve(calendarWeekLayout) }

    /// `first_day_of_week` normalised to 0 (Sunday) … 6, default Sunday.
    public var firstDay: Int { CalendarMath.normalizeFirstDay(firstDayOfWeek) }
}

/// `GET /api/v1/settings/api-key` (admin only).
public struct AppApiKey: Decodable, Sendable {
    public let apiKey: String
}

/// `PUT /api/v1/settings {"calendar_week_card_style": …}`.
public struct WeekCardStylePatch: Encodable, Sendable {
    public let calendarWeekCardStyle: String
    public init(_ style: WeekCardStyle) { calendarWeekCardStyle = style.rawValue }
}

// MARK: - Enums

/// The five Calendar views, in the web's order (Sonarr's Month | Week | Forecast | Day | Agenda).
public enum CalendarViewMode: String, CaseIterable, Sendable, Hashable {
    case month, week, forecast, day, agenda

    public var label: String {
        switch self {
        case .month: return "Month"
        case .week: return "Week"
        case .forecast: return "Forecast"
        case .day: return "Day"
        case .agenda: return "Agenda"
        }
    }

    /// `resolveCalendarView`: remembered view → server default → `agenda` (phone fallback).
    public static func resolve(stored: String?, settingDefault: String?) -> CalendarViewMode {
        if let stored, let view = CalendarViewMode(rawValue: stored) { return view }
        if let settingDefault, let view = CalendarViewMode(rawValue: settingDefault) { return view }
        return .agenda
    }
}

public enum WeekCardStyle: String, CaseIterable, Sendable, Hashable {
    case landscape, portrait, compact, accent

    public static func resolve(_ value: String?) -> WeekCardStyle {
        value.flatMap(WeekCardStyle.init(rawValue:)) ?? .landscape
    }

    public var label: String {
        switch self {
        case .landscape: return "Landscape still"
        case .portrait: return "Portrait poster"
        case .compact: return "Compact"
        case .accent: return "Tier accent"
        }
    }

    public var detail: String {
        switch self {
        case .landscape: return "Wide episode still with the air time overlaid, then the coverage rails. (Default)"
        case .portrait: return "Show poster beside the title, with full-width coverage rails underneath."
        case .compact: return "Tiny poster, mono start time and title — fits the most episodes per band."
        case .accent: return "Card tinted by its quality tier (blue HD, gold 4K) with a small poster."
        }
    }
}

public enum MovieReleaseType: String, CaseIterable, Sendable, Hashable {
    case theatrical, digital, physical

    public var label: String {
        switch self {
        case .theatrical: return "Theatrical"
        case .digital: return "Digital"
        case .physical: return "Physical"
        }
    }
}

/// The calendar's status vocabulary (`lib/status.ts` keys the legend and rails use).
public enum CalendarStatusKey: String, CaseIterable, Sendable, Hashable {
    case downloaded, downloading, missing, unaired

    public var label: String {
        switch self {
        case .downloaded: return "Downloaded"
        case .downloading: return "Downloading"
        case .missing: return "Missing"
        case .unaired: return "Unaired"
        }
    }
}

/// The client-side media filter chips.
public enum CalendarMediaFilter: String, CaseIterable, Sendable, Hashable {
    case all, series, movies, anime

    public var label: String {
        switch self {
        case .all: return "All"
        case .series: return "Series"
        case .movies: return "Movies"
        case .anime: return "Anime"
        }
    }

    public func matches(_ entry: CalendarEntry) -> Bool {
        switch self {
        case .all: return true
        case .anime: return entry.isAnime
        case .movies: return entry.isMovie
        case .series: return !entry.isMovie && !entry.isAnime
        }
    }
}

// MARK: - Entry helpers

extension CalendarEntry {
    public var isMovie: Bool { type == "movie" || mediaKind == .movie }

    public var movieReleaseType: MovieReleaseType? {
        releaseType.flatMap(MovieReleaseType.init(rawValue:))
    }

    /// `airInstant`: the precise air instant, else the air date read as UTC midnight.
    public var airInstant: Date? {
        CalendarMath.parseUTC(airDatetime ?? date)
    }

    /// The precise air instant only (nil for date-only entries).
    public var airDatetimeInstant: Date? {
        airDatetime.flatMap(CalendarMath.parseUTC)
    }

    /// `entryLocalIso`: the local calendar day an entry belongs to.
    public func localDay(_ calendar: Calendar = .current) -> String {
        if let instant = airDatetimeInstant { return CalendarMath.iso(instant, calendar) }
        return String(date.prefix(10))
    }

    /// `episodeHasAired`.
    public func hasAired(now: Date = Date()) -> Bool {
        guard let instant = airInstant else { return false }
        return instant <= now
    }

    /// `entryLabel`: `Theatrical` / `Release` / `#28` / `S01·E05` / `Episode`.
    public var label: String {
        if isMovie { return movieReleaseType?.label ?? "Release" }
        if isAnime, let abs = absoluteNumber { return EpisodeCode.absolute(abs) }
        if let s = seasonNumber, let e = episodeNumber { return EpisodeCode.episode(season: s, episode: e) }
        return "Episode"
    }

    /// Anime keeps its season·episode as well as the absolute number.
    public var animeSE: String? {
        guard isAnime, let s = seasonNumber, let e = episodeNumber else { return nil }
        return EpisodeCode.episode(season: s, episode: e)
    }

    /// The code shown on rows and week cards.
    public var code: String { animeSE ?? label }

    /// `entryAirTime`: `9:00 PM – 9:50 PM`, or the start alone without a runtime.
    public func airTime(_ timeZone: TimeZone = .current) -> String? {
        guard let start = airDatetimeInstant else { return nil }
        let first = CalendarMath.clock(start, timeZone)
        guard let minutes = runtime, minutes > 0 else { return first }
        return "\(first) – \(CalendarMath.clock(start.addingTimeInterval(Double(minutes) * 60), timeZone))"
    }

    /// `entryAirStart`: the start alone (`9:00 PM`).
    public func airStart(_ timeZone: TimeZone = .current) -> String? {
        airDatetimeInstant.map { CalendarMath.clock($0, timeZone) }
    }

    public var isGrabbing: Bool { editions.contains { $0.status == .downloading } }

    /// `editionStatusKey`: unaired-aware. A missing edition on an entry that has not
    /// aired yet reads as `unaired` (blue) instead of `missing` (amber).
    public func statusKey(for edition: CalendarEdition, now: Date = Date()) -> CalendarStatusKey {
        switch edition.status {
        case .downloaded: return .downloaded
        case .downloading: return .downloading
        default: return hasAired(now: now) ? .missing : .unaired
        }
    }

    /// The distinct status keys across a set of entries, legend-ordered (day-strip dots).
    public static func statusKeys(_ entries: [CalendarEntry], now: Date = Date()) -> [CalendarStatusKey] {
        var seen = Set<CalendarStatusKey>()
        for entry in entries {
            for edition in entry.editions { seen.insert(entry.statusKey(for: edition, now: now)) }
        }
        return Array(CalendarStatusKey.allCases.filter { seen.contains($0) }.prefix(3))
    }
}

// MARK: - Season drops (Week view)

public struct SeasonTierAggregate: Sendable, Hashable {
    public let tier: QualityTier
    public var done: Int
    public var total: Int
    public var grabbing: Int
}

/// ≥ 3 episodes of one series on the same day, shown as one card.
public struct SeasonGroup: Sendable, Hashable {
    public let entries: [CalendarEntry]
    public let tiers: [SeasonTierAggregate]
    public var item: CalendarEntry { entries[0] }
}
