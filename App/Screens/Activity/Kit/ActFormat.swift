import SwiftUI
import FusionhaKit

// MARK: Formatting (lib/format)

enum ActFmt {
    static func date(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        if iso.count == 10 { return Format.day(iso) }
        return Format.timestamp(iso)
    }

    /// The web's `relativeTime`: "just now", "5 minutes ago", "3 days ago".
    static func relative(_ iso: String?, now: Date = Date()) -> String {
        guard let d = date(iso) else { return "" }
        return relative(d, now: now)
    }

    static func relative(_ d: Date, now: Date = Date()) -> String {
        let secs = now.timeIntervalSince(d)
        let future = secs < 0
        let s = abs(secs)
        if s < 45 { return "just now" }
        func phrase(_ n: Int, _ unit: String) -> String {
            let text = "\(n) \(unit)\(n == 1 ? "" : "s")"
            return future ? "in \(text)" : "\(text) ago"
        }
        let mins = Int((s / 60).rounded())
        if mins < 60 { return phrase(max(mins, 1), "minute") }
        let hours = Int((s / 3600).rounded())
        if hours < 24 { return phrase(hours, "hour") }
        let days = Int((s / 86400).rounded())
        if days < 7 { return phrase(days, "day") }
        if days < 30 { return phrase(days / 7, "week") }
        if days < 365 { return phrase(max(days / 30, 1), "month") }
        return phrase(days / 365, "year")
    }

    /// "Oct 4 · 03:52".
    static func dateTime(_ iso: String?) -> String {
        guard let d = date(iso) else { return "" }
        return dateTimeFormatter.string(from: d)
    }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d · HH:mm"
        return f
    }()

    /// "15 Mar 2009".
    static func releaseDate(_ iso: String?) -> String {
        guard let d = date(iso) else { return "" }
        return releaseDateFormatter.string(from: d)
    }

    private static let releaseDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    static func bytes(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = value
        var i = 0
        while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
        return i == 0 ? "\(Int(v)) B" : String(format: "%.1f %@", v, units[i])
    }

    static func rate(_ bps: Double) -> String {
        guard bps > 0, bps.isFinite else { return "—" }
        let mb = bps / (1024 * 1024)
        if mb >= 1 { return mb >= 100 ? "\(Int(mb.rounded())) MB/s" : String(format: "%.1f MB/s", mb) }
        return "\(max(1, Int((bps / 1024).rounded()))) KB/s"
    }

    static func mbps(_ bps: Double) -> String {
        guard bps > 0, bps.isFinite else { return "0.0" }
        return String(format: "%.1f", bps / (1024 * 1024))
    }

    static func etaShort(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "—" }
        if seconds < 5 { return "now" }
        if seconds < 60 { return "\(Int(seconds.rounded()))s" }
        let mins = Int((seconds / 60).rounded())
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60, m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    static func etaApprox(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return "—" }
        if seconds < 60 { return "<1 min" }
        let mins = Int((seconds / 60).rounded())
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60, m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    static func countdown(_ iso: String?, now: Date = Date()) -> String {
        guard let d = date(iso) else { return "—" }
        let remaining = Int(d.timeIntervalSince(now).rounded())
        if remaining <= 0 { return "due now" }
        if remaining < 3600 { return "in \(remaining / 60):\(String(format: "%02d", remaining % 60))" }
        return "in \(remaining / 3600)h \(String(format: "%02d", (remaining % 3600) / 60))m"
    }

    static func quality(_ raw: String) -> String { QualityLabels.text(raw) }

    static func protocolLabel(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch raw.uppercased() {
        case "USENET": return "Usenet"
        case "TORRENT": return "Torrent"
        default: return raw.capitalized
        }
    }

    static func plural(_ n: Int, _ word: String, _ pluralWord: String? = nil) -> String {
        "\(n) \(n == 1 ? word : (pluralWord ?? word + "s"))"
    }

    static func taskLabel(_ name: String) -> String {
        let labels = ["rss_sync": "RSS Sync", "import_poll": "Import & Download Poll", "metadata_refresh": "Metadata Refresh",
                      "metadata-refresh": "Full catalog sync", "metadata-refresh-active": "Active series sync",
                      "air-times": "Air-times", "anime-ids": "Anime IDs"]
        if let label = labels[name] { return label }
        return name.replacingOccurrences(of: "[_-]+", with: " ", options: .regularExpression)
            .split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
