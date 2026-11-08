import Foundation

/// The unit a duration setting is stored in on the server. The raw value is
/// its length in seconds.
public enum DurationUnit: Double, CaseIterable, Sendable {
    case seconds = 1
    case minutes = 60
    case hours = 3600
    case days = 86400

    /// The wheel column's label in the custom duration sheet.
    public var short: String {
        switch self {
        case .seconds: "sec"
        case .minutes: "min"
        case .hours: "hours"
        case .days: "days"
        }
    }

    /// The most a column shows when a larger column sits to its left.
    public var carry: Int {
        switch self {
        case .seconds, .minutes: 60
        case .hours: 24
        case .days: 365
        }
    }
}

/// How Settings says a length of time: "12 hours", "30 minutes", "2 weeks",
/// and "12 h 30 min" for a value that is not a whole unit.
public enum DurationFormat {
    private static let week = 604_800

    /// The value shown on a duration row's menu button.
    public static func short(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s == 0 { return "0 minutes" }
        if s % week == 0 { return plural(s / week, "week") }
        let parts = split(s)
        let nonzero = parts.filter { $0.1 > 0 }
        if nonzero.count == 1, let only = nonzero.first { return plural(only.1, word(only.0)) }
        return nonzero.prefix(2).map { "\($0.1) \(abbreviation($0.0))" }.joined(separator: " ")
    }

    /// The full spoken form, for the custom sheet's footer and VoiceOver:
    /// "12 hours 30 minutes".
    public static func long(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s == 0 { return "0 minutes" }
        if s % week == 0 { return plural(s / week, "week") }
        return split(s).filter { $0.1 > 0 }.map { plural($0.1, word($0.0)) }.joined(separator: " ")
    }

    /// A value spread over the sheet's wheel columns (largest first). The
    /// first column takes everything above it; the rest wrap at their carry.
    public static func parts(_ seconds: Double, columns: [DurationUnit]) -> [Int] {
        var rest = max(0, Int(seconds.rounded()))
        var out: [Int] = []
        for unit in columns {
            let size = Int(unit.rawValue)
            out.append(rest / size)
            rest %= size
        }
        return out
    }

    /// The inverse of `parts`.
    public static func seconds(_ parts: [Int], columns: [DurationUnit]) -> Double {
        Double(zip(parts, columns).reduce(0) { $0 + $1.0 * Int($1.1.rawValue) })
    }

    private static func split(_ s: Int) -> [(DurationUnit, Int)] {
        let all: [DurationUnit] = [.days, .hours, .minutes, .seconds]
        return Array(zip(all, parts(Double(s), columns: all)))
    }

    private static func word(_ unit: DurationUnit) -> String {
        switch unit {
        case .seconds: "second"
        case .minutes: "minute"
        case .hours: "hour"
        case .days: "day"
        }
    }

    private static func abbreviation(_ unit: DurationUnit) -> String {
        switch unit {
        case .seconds: "s"
        case .minutes: "min"
        case .hours: "h"
        case .days: "d"
        }
    }

    private static func plural(_ n: Int, _ word: String) -> String {
        "\(n) \(word)\(n == 1 ? "" : "s")"
    }
}

/// The worded day offset for Availability delay: "5 days before",
/// "On the day", "3 days after".
public enum DayOffsetFormat {
    public static func text(_ days: Int) -> String {
        if days == 0 { return "On the day" }
        let n = abs(days)
        return "\(n) day\(n == 1 ? "" : "s") \(days < 0 ? "before" : "after")"
    }
}
