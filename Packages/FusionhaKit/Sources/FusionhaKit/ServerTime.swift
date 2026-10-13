import Foundation

/// The server's clock, read one way everywhere.
///
/// fusionha sends datetimes as NAIVE UTC with no zone (`2026-10-02T02:52:39.007478`),
/// sometimes with `Z` or an offset, and plain days as `2026-10-02`. A naive value
/// read as local time is wrong by the viewer's offset (the web lost its "Just
/// finished" lane for every non-UTC user to this), so every parse appends `Z`
/// first. A bare day is UTC midnight.
public enum ServerTime {

    /// Parses a server timestamp or day, or nil when it isn't one.
    public static func parse(_ raw: String?) -> Date? {
        guard var text = raw?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if text.count == 10 { return day.date(from: text) }
        // `2026-10-02 02:52:39` (a space for the T) is the same instant.
        if text.count > 10 {
            let gap = text.index(text.startIndex, offsetBy: 10)
            if text[gap] == " " { text.replaceSubrange(gap...gap, with: "T") }
        }
        if text.range(of: #"([zZ]|[+-]\d\d:?\d\d)$"#, options: .regularExpression) == nil { text += "Z" }
        if let d = fractional.date(from: text) ?? plain.date(from: text) { return d }
        // Microsecond fractions (6 digits) trip ISO8601DateFormatter: trim to 3.
        if let dot = text.firstIndex(of: "."),
           let end = text[dot...].firstIndex(where: { !$0.isNumber && $0 != "." }) {
            let fraction = text[text.index(after: dot)..<end]
            return fractional.date(from: String(text[..<dot]) + "." + String(fraction.prefix(3)) + String(text[end...]))
        }
        return nil
    }

    /// The viewer's local midnight today as a UTC instant (`…Z`), for
    /// `GET /activity/idle-summary?today_start=` ("today" means the viewer's
    /// day), the same form the web sends (`localMidnightIso`).
    public static func localMidnightISO(now: Date = Date(), calendar: Calendar = .current) -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: calendar.startOfDay(for: now))
    }

    // Parsing only (never mutated after creation), so one shared instance each.
    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
