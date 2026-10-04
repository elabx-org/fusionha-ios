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
    public let voicePlayful: Bool?
    public let animationsEnabled: Bool?

    public init(firstDayOfWeek: Int? = nil, calendarDefaultView: String? = nil, calendarWeekCardStyle: String? = nil,
                voicePlayful: Bool? = nil, animationsEnabled: Bool? = nil) {
        self.firstDayOfWeek = firstDayOfWeek
        self.calendarDefaultView = calendarDefaultView
        self.calendarWeekCardStyle = calendarWeekCardStyle
        self.voicePlayful = voicePlayful
        self.animationsEnabled = animationsEnabled
    }

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

    /// `entryLabel`: `Theatrical` / `Release` / `#28` / `S1·E5` / `Episode`.
    public var label: String {
        if isMovie { return movieReleaseType?.label ?? "Release" }
        if isAnime, let abs = absoluteNumber { return "#\(abs)" }
        if let s = seasonNumber, let e = episodeNumber { return "S\(s)·E\(e)" }
        return "Episode"
    }

    /// Anime keeps its season·episode as well as the absolute number.
    public var animeSE: String? {
        guard isAnime, let s = seasonNumber, let e = episodeNumber else { return nil }
        return "S\(s)·E\(e)"
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

// MARK: - Date maths

public enum CalendarMath {
    public static let monthNames = ["January", "February", "March", "April", "May", "June", "July",
                                    "August", "September", "October", "November", "December"]
    public static let dow = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    public static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    public static let forecastDays = 7

    /// A Gregorian calendar in the given zone (the web uses the browser's local zone).
    public static func gregorian(_ timeZone: TimeZone = .current) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }

    public static func normalizeFirstDay(_ value: Int?) -> Int {
        guard let value else { return 0 }
        return ((value % 7) + 7) % 7
    }

    /// Parses `2026-10-04T21:00:00Z`, a naive `2026-10-04T21:00:00` (read as UTC) or a
    /// bare `2026-10-04` (UTC midnight), like the web's `parseUtc`.
    public static func parseUTC(_ raw: String) -> Date? {
        var text = raw
        let hasTime = text.contains("T")
        let hasZone = text.range(of: #"(Z|[+-]\d{2}:?\d{2})$"#, options: .regularExpression) != nil
        if hasTime && !hasZone { text += "Z" }
        if !hasTime { text += "T00:00:00Z" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: text) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: text)
    }

    public static func iso(_ date: Date, _ calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 1, c.day ?? 1)
    }

    /// Local midnight of an ISO day.
    public static func date(_ iso: String, _ calendar: Calendar = .current) -> Date? {
        let parts = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    public static func shift(_ iso: String, days: Int, _ calendar: Calendar = .current) -> String {
        guard let d = date(iso, calendar), let n = calendar.date(byAdding: .day, value: days, to: d) else { return iso }
        return self.iso(n, calendar)
    }

    public static func addDays(_ date: Date, _ n: Int, _ calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: n, to: calendar.startOfDay(for: date)) ?? date
    }

    /// 0 = Sunday, like JS `getDay()`.
    public static func weekday(_ date: Date, _ calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: date) - 1
    }

    public static func weekday(iso: String, _ calendar: Calendar = .current) -> Int {
        date(iso, calendar).map { weekday($0, calendar) } ?? 0
    }

    public static func clock(_ date: Date, _ timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = timeZone
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    // Month

    public static func monthStart(_ date: Date, _ calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    public static func addMonths(_ date: Date, _ n: Int, _ calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: n, to: monthStart(date, calendar)) ?? date
    }

    public static func monthBounds(_ date: Date, _ calendar: Calendar = .current) -> (start: String, end: String) {
        let start = monthStart(date, calendar)
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
        return (iso(start, calendar), iso(end, calendar))
    }

    public static func monthTitle(_ date: Date, _ calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return "\(monthNames[(c.month ?? 1) - 1]) \(c.year ?? 0)"
    }

    /// `buildMonthGrid`: leading blanks, the month's days, trailing blanks to a full week.
    public static func monthGrid(_ date: Date, firstDay: Int, _ calendar: Calendar = .current) -> [String?] {
        let start = monthStart(date, calendar)
        let days = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let blanks = (weekday(start, calendar) - normalizeFirstDay(firstDay) + 7) % 7
        var cells: [String?] = Array(repeating: nil, count: blanks)
        for d in 0..<days { cells.append(iso(addDays(start, d, calendar), calendar)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    public static func weekdayHeaders(firstDay: Int) -> [String] {
        let fd = normalizeFirstDay(firstDay)
        return (0..<7).map { dow[(fd + $0) % 7] }
    }

    // Week

    public static func weekStart(_ date: Date, firstDay: Int, _ calendar: Calendar = .current) -> Date {
        let back = (weekday(date, calendar) - normalizeFirstDay(firstDay) + 7) % 7
        return addDays(date, -back, calendar)
    }

    public static func weekDays(_ date: Date, firstDay: Int, _ calendar: Calendar = .current) -> [String] {
        let start = weekStart(date, firstDay: firstDay, calendar)
        return (0..<7).map { iso(addDays(start, $0, calendar), calendar) }
    }

    /// `Oct 4 – 10, 2026` · `Sep 27 – Oct 3, 2026` · `Dec 27, 2026 – Jan 2, 2027`.
    public static func rangeTitle(from start: Date, to end: Date, _ calendar: Calendar = .current) -> String {
        let s = calendar.dateComponents([.year, .month, .day], from: start)
        let e = calendar.dateComponents([.year, .month, .day], from: end)
        let sMon = String(monthNames[(s.month ?? 1) - 1].prefix(3))
        let eMon = String(monthNames[(e.month ?? 1) - 1].prefix(3))
        if s.year != e.year {
            return "\(sMon) \(s.day ?? 1), \(s.year ?? 0) – \(eMon) \(e.day ?? 1), \(e.year ?? 0)"
        }
        if s.month != e.month {
            return "\(sMon) \(s.day ?? 1) – \(eMon) \(e.day ?? 1), \(e.year ?? 0)"
        }
        return "\(sMon) \(s.day ?? 1) – \(e.day ?? 1), \(e.year ?? 0)"
    }

    public static func weekTitle(_ date: Date, firstDay: Int, _ calendar: Calendar = .current) -> String {
        let start = weekStart(date, firstDay: firstDay, calendar)
        return rangeTitle(from: start, to: addDays(start, 6, calendar), calendar)
    }

    public static func forecastTitle(_ anchor: Date, _ calendar: Calendar = .current) -> String {
        rangeTitle(from: anchor, to: addDays(anchor, forecastDays - 1, calendar), calendar)
    }

    /// `Sunday, October 4, 2026`.
    public static func dayTitle(_ date: Date, _ calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(weekdayNames[weekday(date, calendar)]), \(monthNames[(c.month ?? 1) - 1]) \(c.day ?? 1), \(c.year ?? 0)"
    }

    /// `Sun, Oct 4` (the agenda date rail's accessibility label).
    public static func agendaDayLabel(_ iso: String, _ calendar: Calendar = .current) -> String {
        guard let d = date(iso, calendar) else { return iso }
        let c = calendar.dateComponents([.month, .day], from: d)
        return "\(dow[weekday(d, calendar)]), \(monthNames[(c.month ?? 1) - 1].prefix(3)) \(c.day ?? 1)"
    }

    /// `Sunday, October 4` (the week day chips' accessibility label).
    public static func weekDayLabel(_ iso: String, _ calendar: Calendar = .current) -> String {
        guard let d = date(iso, calendar) else { return iso }
        let c = calendar.dateComponents([.month, .day], from: d)
        return "\(weekdayNames[weekday(d, calendar)]), \(monthNames[(c.month ?? 1) - 1]) \(c.day ?? 1)"
    }

    // Grouping

    /// `sortDayEntries`: timed entries first by instant, then date-only ones in server order.
    public static func sortDay(_ entries: [CalendarEntry]) -> [CalendarEntry] {
        entries.enumerated().map { (offset: $0.offset, entry: $0.element, at: $0.element.airDatetimeInstant) }
            .sorted { a, b in
                switch (a.at, b.at) {
                case let (x?, y?): return x == y ? a.offset < b.offset : x < y
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return a.offset < b.offset
                }
            }
            .map { $0.entry }
    }

    /// `groupByIso`: entries keyed by local day, each day sorted.
    public static func groupByDay(_ entries: [CalendarEntry], _ calendar: Calendar = .current) -> [String: [CalendarEntry]] {
        var out: [String: [CalendarEntry]] = [:]
        for entry in entries { out[entry.localDay(calendar), default: []].append(entry) }
        return out.mapValues(sortDay)
    }

    /// `groupWeekDay`: season drops (≥ 3 same-day episodes of one series) and singles.
    public static func groupWeekDay(_ entries: [CalendarEntry]) -> (seasons: [SeasonGroup], singles: [CalendarEntry]) {
        var counts: [Int: Int] = [:]
        for e in entries where e.type == "episode" { counts[e.itemId, default: 0] += 1 }
        let seasonIds = Set(counts.filter { $0.value >= 3 }.keys)
        var singles: [CalendarEntry] = []
        var grouped: [Int: [CalendarEntry]] = [:]
        var order: [Int] = []
        for e in entries {
            if e.type == "episode" && seasonIds.contains(e.itemId) {
                if grouped[e.itemId] == nil { order.append(e.itemId) }
                grouped[e.itemId, default: []].append(e)
            } else {
                singles.append(e)
            }
        }
        let seasons = order.map { id -> SeasonGroup in
            let list = grouped[id] ?? []
            var tiers: [SeasonTierAggregate] = []
            for ep in list {
                for ed in ep.editions where ed.monitored {
                    var index = tiers.firstIndex { $0.tier == ed.tier }
                    if index == nil {
                        tiers.append(SeasonTierAggregate(tier: ed.tier, done: 0, total: 0, grabbing: 0))
                        index = tiers.count - 1
                    }
                    tiers[index!].total += 1
                    if ed.status == .downloaded { tiers[index!].done += 1 } else if ed.status == .downloading { tiers[index!].grabbing += 1 }
                }
            }
            return SeasonGroup(entries: list, tiers: tiers)
        }
        return (seasons, singles)
    }
}
