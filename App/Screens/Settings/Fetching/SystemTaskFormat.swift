import SwiftUI
import FusionhaKit

// MARK: Format

/// `system-tasks-format.ts`: labels, schedule, durations, last-run and countdown.
enum SystemTaskFormat {
    private static let labels: [String: String] = [
        "rss_sync": "RSS Sync",
        "import_poll": "Import & Download Poll",
        "metadata_refresh": "Metadata Refresh",
        "metadata-refresh": "Full catalog sync",
        "metadata-refresh-active": "Active series sync",
        "air-times": "Air-times",
        "anime-ids": "Anime IDs",
    ]

    static func label(_ name: String) -> String {
        if let known = labels[name] { return known }
        return name.split(whereSeparator: { $0 == "_" || $0 == "-" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func schedule(_ seconds: Int) -> String {
        seconds <= 0 ? "Runs with each sync" : "Every \(interval(seconds))"
    }

    static func interval(_ seconds: Int) -> String {
        if seconds <= 0 { return "—" }
        if seconds % 3600 == 0 {
            let h = seconds / 3600
            return "\(h) hour\(h == 1 ? "" : "s")"
        }
        if seconds % 60 == 0 { return "\(seconds / 60) min" }
        return "\(seconds) sec"
    }

    static func duration(_ seconds: Double) -> String {
        if seconds.isNaN { return "—" }
        if seconds < 1 { return "\(Int((seconds * 1000).rounded()))ms" }
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let m = Int(seconds / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60).rounded())
        return "\(m)m \(String(format: "%02d", s))s"
    }

    static func lastRun(_ iso: String?, now: Date) -> String {
        guard let iso else { return "Never" }
        guard let then = FetchFormat.date(iso) else { return "—" }
        let secs = max(0, Int(now.timeIntervalSince(then).rounded()))
        if secs < 45 { return "just now" }
        if secs < 3600 { return "\(Int((Double(secs) / 60).rounded())) min ago" }
        if secs < 86_400 { return "\(Int((Double(secs) / 3600).rounded())) hr ago" }
        let d = Int((Double(secs) / 86_400).rounded())
        return "\(d) day\(d == 1 ? "" : "s") ago"
    }

    static func countdown(_ iso: String?, now: Date) -> (text: String, due: Bool) {
        guard let target = FetchFormat.date(iso) else { return ("—", false) }
        let remaining = Int(target.timeIntervalSince(now).rounded())
        if remaining <= 0 { return ("due now", true) }
        if remaining < 3600 {
            return ("in \(remaining / 60):\(String(format: "%02d", remaining % 60))", false)
        }
        return ("in \(remaining / 3600)h \(String(format: "%02d", (remaining % 3600) / 60))m", false)
    }

    /// The group remembers its open state (default open), like the web's localStorage key.
    static var groupOpen: Bool {
        get { UserDefaults.standard.string(forKey: "fusionha.system-tasks.group.library-metadata.open") != "closed" }
        set { UserDefaults.standard.set(newValue ? "open" : "closed", forKey: "fusionha.system-tasks.group.library-metadata.open") }
    }
}
