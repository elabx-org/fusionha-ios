import Foundation

/// The download figures the widgets show beside progress: average speed since
/// the grab and short size / speed labels. The queue reports no live speed,
/// so the rate is what arrived divided by the download's age.
public enum WidgetDownloadStats {
    /// Bytes per second since the grab; nil when stalled, finished or unknown.
    public static func rate(size: Double, sizeleft: Double, ageSeconds: Double?, stalled: Bool) -> Double? {
        guard !stalled, let age = ageSeconds, age > 0, size > 0, sizeleft > 0 else { return nil }
        let done = size - sizeleft
        guard done > 0 else { return nil }
        let rate = done / age
        return rate.isFinite ? rate : nil
    }

    /// `24.1 MB/s`.
    public static func rateLabel(_ bytesPerSecond: Double) -> String {
        DetailText.bytes(bytesPerSecond) + "/s"
    }

    /// `41.2 GB`.
    public static func sizeLabel(_ bytes: Double) -> String {
        DetailText.bytes(bytes)
    }
}
