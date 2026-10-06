import Foundation

extension WidgetFeeds {
    /// `12m left`, `2h 5m left`, from progress over time in the queue; nil when
    /// there is too little progress to tell or the download is stalled.
    public static func timeLeft(fraction: Double, ageSeconds: Double?, stalled: Bool = false) -> String? {
        guard !stalled, let age = ageSeconds, age > 0, fraction >= 0.02, fraction < 1 else { return nil }
        let seconds = age * (1 - fraction) / fraction
        guard seconds.isFinite, seconds < 86_400 * 7 else { return nil }
        let minutes = Int((seconds / 60).rounded())
        if minutes < 1 { return "<1m left" }
        if minutes < 60 { return "\(minutes)m left" }
        let h = minutes / 60, m = minutes % 60
        if h >= 24 { return "\(h / 24)d \(h % 24)h left" }
        return m == 0 ? "\(h)h left" : "\(h)h \(m)m left"
    }
}
