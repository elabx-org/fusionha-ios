import Foundation

// MARK: - When to grab it  (timeline.ts)

public struct TimelineDates: Sendable, Hashable {
    public var releaseDate: String?
    public var inCinemas: String?
    public var digitalRelease: String?
    public var physicalRelease: String?
    public var estimateDate: String?
    public var estimateIsEstimated: Bool

    public init(releaseDate: String? = nil, inCinemas: String? = nil, digitalRelease: String? = nil,
                physicalRelease: String? = nil, estimateDate: String? = nil, estimateIsEstimated: Bool = false) {
        self.releaseDate = releaseDate
        self.inCinemas = inCinemas
        self.digitalRelease = digitalRelease
        self.physicalRelease = physicalRelease
        self.estimateDate = estimateDate
        self.estimateIsEstimated = estimateIsEstimated
    }
}

public struct TimelineStop: Sendable, Hashable {
    /// `announced` / `inCinemas` / `released` (the minimum-availability value).
    public let key: String
    public let label: String
    public let date: String?
    public let dateText: String?
    /// `dateText` without its "est. " prefix.
    public let dateBody: String?
    public let estimated: Bool
    public let when: String?
    /// 0–100 along the track.
    public let pos: Double
}

public struct ReleaseTimelineModel: Sendable, Hashable {
    public let stops: [TimelineStop]
    /// Today's position, 0–100, or nil when no stop is dated.
    public let today: Double?

    public static let stopPos: [String: Double] = ["announced": 12, "inCinemas": 50, "released": 88]
    static let todayEnd: Double = 96
    static let easeDays: Double = 180
    private static let utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// ISO date → UTC epoch day, or nil when malformed.
    public static func isoDay(_ iso: String?) -> Int? {
        guard let iso, iso.count >= 10 else { return nil }
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        guard let date = utc.date(from: DateComponents(year: y, month: m, day: d)) else { return nil }
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// The viewer's calendar day as an epoch day (matches `isoDay`).
    public static func localDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let iso = String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
        return isoDay(iso) ?? 0
    }

    /// `2026-12-18` → "18 Dec 2026"; estimated → "est. Dec 2026".
    public static func formatStopDate(_ iso: String, estimated: Bool = false) -> String {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), (1...12).contains(m), let d = Int(parts[2]) else { return iso }
        let my = "\(months[m - 1]) \(parts[0])"
        return estimated ? "est. \(my)" : "\(d) \(my)"
    }

    private static func plural(_ n: Int, _ unit: String) -> String { "\(n) \(unit)\(n == 1 ? "" : "s")" }

    /// "right away" / "tomorrow" / "in 5 days" / "in 3 weeks" / "in ~6 months".
    public static func relativeUntil(_ days: Int, estimated: Bool = false) -> String {
        if days <= 0 { return estimated ? "any day now" : "right away" }
        let approx = estimated ? "~" : ""
        if days == 1 && !estimated { return "tomorrow" }
        if days < 14 { return "in \(approx)\(plural(days, "day"))" }
        if days < 60 { return "in \(approx)\(plural(Int((Double(days) / 7).rounded()), "week"))" }
        if days < 548 { return "in \(approx)\(plural(Int((Double(days) / 30.44).rounded()), "month"))" }
        return "in \(approx)\(plural(Int((Double(days) / 365.25).rounded()), "year"))"
    }

    private static func clamp(_ n: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, n)) }

    /// The stops either side of Today's position (nil = the track edge).
    public static func todayBounds(_ pos: Double) -> (lo: Double?, hi: Double?) {
        let at = stopPos.values.sorted()
        return (at.filter { $0 <= pos }.last, at.first { $0 > pos })
    }

    public static func build(_ dates: TimelineDates, today: Date = Date(), calendar: Calendar = .current) -> ReleaseTimelineModel {
        let cinemaRaw = isoDay(dates.inCinemas) != nil ? dates.inCinemas : dates.releaseDate
        let cinema = isoDay(cinemaRaw) != nil ? cinemaRaw : nil
        // Released: the grab gate's estimate, else the earlier home date.
        var released: String?
        var releasedEstimated = false
        if let est = dates.estimateDate, isoDay(est) != nil {
            released = est
            releasedEstimated = dates.estimateIsEstimated
        } else {
            released = [dates.digitalRelease, dates.physicalRelease].compactMap { $0 }
                .filter { isoDay($0) != nil }
                .min { (isoDay($0) ?? 0) < (isoDay($1) ?? 0) }
        }
        let cDay = isoDay(cinema)
        let rDay = isoDay(released)
        let tDay = localDay(today, calendar: calendar)
        var anchors: [(day: Int, pos: Double)] = []
        if let cDay { anchors.append((cDay, stopPos["inCinemas"]!)) }
        if let rDay { anchors.append((rDay, stopPos["released"]!)) }
        let nextAfterLast = rDay == nil && cDay != nil ? stopPos["released"]! : todayEnd
        let releasedText = released.map { formatStopDate($0, estimated: releasedEstimated) }

        var todayPos: Double?
        if let first = anchors.first, let last = anchors.last {
            if tDay < first.day {
                let f = clamp(1 - Double(first.day - tDay) / easeDays, 0.1, 0.9)
                todayPos = stopPos["announced"]! + (first.pos - stopPos["announced"]!) * f
            } else if tDay >= last.day {
                let f = clamp(Double(tDay - last.day) / easeDays, 0.1, 0.9)
                todayPos = last.pos + (nextAfterLast - last.pos) * f
            } else {
                todayPos = first.pos + Double(tDay - first.day) / Double(last.day - first.day) * (last.pos - first.pos)
            }
        }
        let cinemaText = cinema.map { formatStopDate($0) } ?? "date unknown"
        let stops = [
            TimelineStop(key: "announced", label: "Announced", date: nil, dateText: "now", dateBody: "now",
                         estimated: false, when: "right away", pos: stopPos["announced"]!),
            TimelineStop(key: "inCinemas", label: "In cinemas", date: cinema, dateText: cinemaText, dateBody: cinemaText,
                         estimated: false, when: cDay.map { relativeUntil($0 - tDay) }, pos: stopPos["inCinemas"]!),
            TimelineStop(key: "released", label: "Released", date: released, dateText: releasedText,
                         dateBody: releasedText.map { releasedEstimated && $0.hasPrefix("est. ") ? String($0.dropFirst(5)) : $0 },
                         estimated: released != nil && releasedEstimated,
                         when: rDay.map { relativeUntil($0 - tDay, estimated: releasedEstimated) }, pos: stopPos["released"]!),
        ]
        return ReleaseTimelineModel(stops: stops, today: todayPos)
    }

    /// A confirmed (not estimated) Released date is today or earlier.
    public func releasedOut(today: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let r = stops.first(where: { $0.key == "released" }), !r.estimated,
              let day = Self.isoDay(r.date) else { return false }
        return day <= Self.localDay(today, calendar: calendar)
    }

    /// Whether an ISO date is today or earlier in the viewer's calendar.
    public static func isPast(_ iso: String, today: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let day = isoDay(iso) else { return false }
        return day <= localDay(today, calendar: calendar)
    }

    /// "Starts searching at **in cinemas** · 18 Dec 2026 · in 3 months".
    public static func caption(_ stop: TimelineStop) -> [SummaryPart] {
        var parts = [SummaryPart("Starts searching at "), SummaryPart(stop.label.lowercased(), strong: true)]
        if stop.key != "announced", let text = stop.dateText { parts.append(SummaryPart(" · \(text)")) }
        if let when = stop.when { parts.append(SummaryPart(" · \(when)")) }
        return parts
    }

    /// "Why?" — when searching starts, and why.
    public static func grabNote(_ stop: TimelineStop, today: Date = Date(), calendar: Calendar = .current) -> [SummaryPart] {
        let t = { (s: String) in SummaryPart(s) }
        let b = { (s: String) in SummaryPart(s, strong: true) }
        if stop.key == "announced" {
            return [t("Searches "), b("right away"), t(". Early releases are often fakes or cam copies.")]
        }
        if stop.key == "inCinemas" {
            let tail = " Expect cinema-quality copies first."
            guard let date = stop.date else {
                return [t("Starts searching "), b("when it opens in cinemas"), t(" (date unknown).\(tail)")]
            }
            if isPast(date, today: today, calendar: calendar) {
                return [t("Searches "), b("right away"), t(". It’s been in cinemas since \(stop.dateText ?? "").")]
            }
            return [t("Starts searching "), b(stop.dateText ?? ""), t(", when it opens in cinemas.\(tail)")]
        }
        if let date = stop.date, !stop.estimated, isPast(date, today: today, calendar: calendar) {
            return [t("Searches "), b("right away"), t(". It’s out for home since \(stop.dateText ?? "").")]
        }
        return [t("Starts searching when it’s "), b("released for home"),
                t(" (digital or disc, \(stop.dateText ?? "date unknown")). The usual choice for good copies.")]
    }
}
