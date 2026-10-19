import Foundation

// The web's phone calendar logic (`calendar/step-nav.ts`, `mobile/day-label.ts`,
// `mobile/run-format.ts`, `day-items.ts`, `entry-model.ts › entryWash`,
// `lib/hooks/useSwipeNav.ts`), kept pure so it can be tested.

extension CalendarViewMode {
    /// `CalendarHeaderMobile › SHORT`: the segment labels under a narrow header.
    public var shortLabel: String {
        switch self {
        case .month: return "Mo"
        case .week: return "Wk"
        case .forecast: return "Fc"
        case .day: return "Day"
        case .agenda: return "Ag"
        }
    }

    /// `phoneSteps`: the phone shows prev/next (and a swipe steps) everywhere
    /// except Forecast and Agenda.
    public var phoneSteps: Bool { self != .forecast && self != .agenda }

    /// `stepNav().stepLabel`.
    public var stepNoun: String {
        switch self {
        case .week: return "week"
        case .day: return "day"
        default: return "month"
        }
    }
}

/// The ambient status wash of a phone card (`entryWash`): any edition grabbing
/// beats an aired episode that is still wanted.
public enum CalendarWash: String, Sendable, Hashable {
    case grab, miss
}

/// One slot of a phone day (`DayItem`): a same-show run or a single entry.
public enum CalendarDayItem: Sendable, Hashable, Identifiable {
    case run(SeasonGroup)
    case entry(CalendarEntry)

    public var id: String {
        switch self {
        case .run(let group): return "run-\(group.item.itemId)"
        case .entry(let e): return "e-\(e.type)-\(e.itemId)-\(e.seasonNumber ?? -1)-\(e.episodeNumber ?? -1)-\(e.date)"
        }
    }

    /// A run reads as aired only once every episode has.
    public func aired(now: Date) -> Bool {
        switch self {
        case .run(let group): return group.entries.allSatisfy { $0.hasAired(now: now) }
        case .entry(let e): return e.hasAired(now: now)
        }
    }
}

extension CalendarEntry {
    /// `entryWash`.
    public func wash(now: Date = Date()) -> CalendarWash? {
        if editions.contains(where: { $0.status == .downloading }) { return .grab }
        if hasAired(now: now) && editions.contains(where: { $0.status == .missing }) { return .miss }
        return nil
    }
}

extension SeasonGroup {
    /// `groupWash`: any episode in flight beats any missing one.
    public func wash(now: Date = Date()) -> CalendarWash? {
        let washes = entries.map { $0.wash(now: now) }
        if washes.contains(.grab) { return .grab }
        return washes.contains(.miss) ? .miss : nil
    }

    /// `runSpan`: first start – last end (`9:00 PM – 10:40 PM`), else nil.
    public func span(_ timeZone: TimeZone = .current) -> String? {
        guard let first = entries.first, let last = entries.last,
              let start = first.airStart(timeZone) else { return nil }
        let end = last.airTime(timeZone)?.components(separatedBy: " – ").last
        if let end, end != start { return "\(start) – \(end)" }
        return start
    }

    /// `runCodes`: `S02·E01–E03` (anime `#28–#30`).
    public var codes: String {
        guard let first = entries.first, let last = entries.last else { return "" }
        if entries.count == 1 { return first.label }
        let tail = last.label.components(separatedBy: "·").last ?? last.label
        return "\(first.label)–\(tail)"
    }
}

extension CalendarMath {
    /// `mobileDayLabel`: `Today · Wed 7` / `Tomorrow · Thu 8` / `Friday 9`.
    public static func mobileDayLabel(_ iso: String, todayIso: String, _ calendar: Calendar = .current) -> String {
        let dow = weekday(iso: iso, calendar)
        let day = Int(iso.suffix(2)) ?? 0
        if iso == todayIso { return "Today · \(self.dow[dow]) \(day)" }
        if iso == shift(todayIso, days: 1, calendar) { return "Tomorrow · \(self.dow[dow]) \(day)" }
        return "\(weekdayNames[dow]) \(day)"
    }

    /// `isoDaysBetween`: every ISO day from `start` to `end` inclusive (capped at 62).
    public static func isoDays(from start: String, to end: String, _ calendar: Calendar = .current) -> [String] {
        var out: [String] = []
        var day = start
        while day <= end && out.count < 62 {
            out.append(day)
            day = shift(day, days: 1, calendar)
        }
        return out
    }

    /// `groupDayItems(entries, 2)`: a day's (sorted) entries as runs and singles,
    /// each run where its first episode airs so the day still reads by the clock.
    public static func dayItems(_ entries: [CalendarEntry], min: Int = 2) -> [CalendarDayItem] {
        let sorted = sortDay(entries)
        let (runs, singles) = groupWeekDay(sorted, min: min)
        let firstRun = Dictionary(runs.map { ($0.item.itemId, $0) }, uniquingKeysWith: { a, _ in a })
        var emitted = Set<Int>()
        var out: [CalendarDayItem] = []
        var singleIndex = 0
        for entry in sorted {
            if let run = firstRun[entry.itemId], entry.type == "episode" {
                if emitted.insert(entry.itemId).inserted { out.append(.run(run)) }
            } else if singleIndex < singles.count {
                out.append(.entry(singles[singleIndex]))
                singleIndex += 1
            }
        }
        return out
    }

    /// `MobileDayBlock`'s today split: aired items first, then the now line, then
    /// the rest. Other days return everything before the line and no line.
    public static func phoneDay(_ items: [CalendarDayItem], isToday: Bool, now: Date)
        -> (before: [CalendarDayItem], after: [CalendarDayItem], showsNow: Bool) {
        guard isToday else { return (items, [], false) }
        let aired = items.filter { $0.aired(now: now) }
        let upcoming = items.filter { !$0.aired(now: now) }
        return (aired, upcoming, true)
    }

    /// `UpNextCard`: the distinct titles (first three) of the next day's entries.
    public static func upNextTitles(_ entries: [CalendarEntry]) -> [String] {
        var seen = Set<String>()
        return Array(entries.compactMap { seen.insert($0.title).inserted ? $0.title : nil }.prefix(3))
    }
}

/// `useSwipeNav`: a horizontal swipe steps the period. The gesture must lock
/// horizontal (10pt slop, 1.5× more horizontal than vertical) and travel 60pt.
public enum CalendarSwipe {
    public static let minTravel: Double = 60
    public static let slop: Double = 10
    public static let ratio: Double = 1.5

    /// -1 for the previous period (swipe right), +1 for the next (swipe left), nil otherwise.
    public static func step(dx: Double, dy: Double) -> Int? {
        guard abs(dx) >= minTravel, abs(dx) >= slop, abs(dx) >= abs(dy) * ratio else { return nil }
        return dx < 0 ? 1 : -1
    }
}
