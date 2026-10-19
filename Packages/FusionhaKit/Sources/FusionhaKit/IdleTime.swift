import Foundation

// MARK: - Queue clear time helpers (web `idle-time.ts` + `formatCountdown`)

public enum IdleTime {
    /// The web's `formatCountdown` result.
    public struct Countdown: Equatable, Sendable {
        public let text: String
        public let seconds: Int
        public let due: Bool
    }

    /// A readiness tile's state: its colour (`ok` green, `soon`/`run` cyan, `warn` amber).
    public enum TileState: Sendable, Equatable { case ok, soon, run, warn }

    /// `in 4:59` under an hour, `in 2h 05m` past it, `due now` once due.
    public static func countdown(to target: Date?, now: Date) -> Countdown {
        guard let target else { return Countdown(text: "—", seconds: 0, due: false) }
        let remaining = Int(target.timeIntervalSince(now).rounded())
        if remaining <= 0 { return Countdown(text: "due now", seconds: 0, due: true) }
        if remaining < 3600 {
            return Countdown(text: "in \(remaining / 60):\(pad(remaining % 60))", seconds: remaining, due: false)
        }
        return Countdown(text: "in \(remaining / 3600)h \(pad((remaining % 3600) / 60))m", seconds: remaining, due: false)
    }

    /// `formatUntil`: `in 2h 05m` an hour or more away, `in 42m` / `in <1m` closer.
    public static func until(_ target: Date, now: Date) -> String {
        let s = max(0, target.timeIntervalSince(now))
        if s >= 3600 { return countdown(to: target, now: now).text }
        if s < 60 { return "in <1m" }
        return "in \(Int(s / 60))m"
    }

    /// A countdown tile's state: running (or due) → `run`, the last minute → `soon`.
    public static func tileState(running: Bool, _ cd: Countdown) -> TileState {
        if running || cd.due { return .run }
        return cd.seconds <= 60 ? .soon : .ok
    }

    /// The countdown ring's fill over `windowSeconds` (the RSS interval; the last hour for search).
    public static func ringFraction(target: Date?, now: Date, windowSeconds: Double) -> Double {
        guard let target, windowSeconds > 0 else { return 0 }
        let left = target.timeIntervalSince(now)
        return min(1, max(0, 1 - left / windowSeconds))
    }

    /// Coming up next's day heading: `Today`, `Tonight` (from 17:00), `Tomorrow`, else the weekday.
    public static func dayLabel(_ day: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return calendar.component(.hour, from: day) >= 17 ? "Tonight" : "Today"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           calendar.isDate(day, inSameDayAs: tomorrow) { return "Tomorrow" }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = locale
        f.dateFormat = "EEEE"
        return f.string(from: day)
    }

    /// `useComingUpFeed`'s range: yesterday → +4 days as local `yyyy-MM-dd`
    /// (calendar dates are the network's air date, which can trail the viewer's day).
    public static func comingUpRange(now: Date, calendar: Calendar = .current) -> (start: String, end: String) {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 4, to: today) ?? today
        return (isoDay(start, calendar), isoDay(end, calendar))
    }

    /// `useRefetchAfterDue`: once a scheduled run is due, refetch after it has had
    /// time to finish (its last duration, or 30 s, plus 5 s; at least 5 s from now),
    /// so a "Syncing…" tile settles to the next countdown. Nil when nothing is pending.
    public static func refetchDelay(_ tasks: IdleSummary.Tasks, now: Date) -> TimeInterval? {
        let due = [tasks.rss, tasks.search, tasks.upgrade].compactMap { $0 }.compactMap { task -> Date? in
            task.nextRunDate.map { $0.addingTimeInterval((task.lastDuration ?? 30) + 5) }
        }.filter { $0 > now }
        guard let first = due.min() else { return nil }
        return max(5, first.timeIntervalSince(now))
    }

    static func isoDay(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    private static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}
