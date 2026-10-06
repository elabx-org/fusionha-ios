import Foundation

/// Smart Stack relevance for the widgets (`TimelineEntryRelevance` scores,
/// 0–1). High only when a widget has something worth surfacing; everything
/// else sits at `low` so the stack keeps the owner's own order.
public enum WidgetStackRelevance {
    public static let low: Float = 0.05

    /// A score that takes effect at `date` (a timeline entry's date).
    public struct Step: Equatable, Sendable {
        public let date: Date
        public let score: Float

        public init(date: Date, score: Float) {
            self.date = date
            self.score = score
        }
    }

    /// Downloading: high while something downloads, a little lower when every
    /// download is stalled, low when idle.
    public static func downloading(active: Int, stalled: Int) -> Float {
        guard active > 0 else { return low }
        return stalled >= active ? 0.6 : 1
    }

    /// Up next: rises as the next airing nears (a day, six hours, an hour,
    /// fifteen minutes out), low once it has aired or with nothing scheduled.
    public static func upNext(secondsUntilAir seconds: TimeInterval) -> Float {
        switch seconds {
        case ..<0: return low
        case ..<(15 * 60): return 1
        case ..<3600: return 0.8
        case ..<(6 * 3600): return 0.5
        case ..<(24 * 3600): return 0.2
        default: return low
        }
    }

    /// The Up next steps from `now` until the item airs, before `until` (the
    /// timeline's reload): one entry per threshold crossed, so the score rises
    /// without spending a reload.
    public static func upNextSteps(airDate: Date?, now: Date, until: Date) -> [Step] {
        guard let air = airDate, air > now else { return [Step(date: now, score: low)] }
        let leads: [TimeInterval] = [24 * 3600, 6 * 3600, 3600, 15 * 60]
        var steps = [Step(date: now, score: upNext(secondsUntilAir: air.timeIntervalSince(now)))]
        for lead in leads {
            let date = air.addingTimeInterval(-lead)
            if date > now, date < until { steps.append(Step(date: date, score: upNext(secondsUntilAir: lead - 1))) }
        }
        return steps.sorted { $0.date < $1.date }
    }

    /// Recently added: a fresh import is worth a look; it fades over a day.
    public static func recent(secondsSinceImport seconds: TimeInterval?) -> Float {
        guard let seconds, seconds >= 0 else { return low }
        switch seconds {
        case ..<3600: return 0.7
        case ..<(6 * 3600): return 0.4
        case ..<(24 * 3600): return 0.15
        default: return low
        }
    }

    /// The Recently added steps from `now` as the newest import ages, before `until`.
    public static func recentSteps(newest: Date?, now: Date, until: Date) -> [Step] {
        guard let newest else { return [Step(date: now, score: low)] }
        var steps = [Step(date: now, score: recent(secondsSinceImport: now.timeIntervalSince(newest)))]
        let ages: [TimeInterval] = [3600, 6 * 3600, 24 * 3600]
        for age in ages {
            let date = newest.addingTimeInterval(age)
            if date > now, date < until { steps.append(Step(date: date, score: recent(secondsSinceImport: age))) }
        }
        return steps
    }

    /// Indexers: raised while one is backing off or unavailable.
    public static func indexers(flagged: Int) -> Float {
        flagged > 0 ? 0.4 : low
    }

    /// Requests & issues: raised while requests wait for approval, less for open issues.
    public static func requests(pending: Int, openIssues: Int) -> Float {
        if pending > 0 { return 0.5 }
        return openIssues > 0 ? 0.3 : low
    }
}
