import Foundation
import MetricKit

/// On-device performance reports from MetricKit, kept for the owner to send us
/// (Settings > Maintenance > Performance reports). The system hands over
/// diagnostics (hangs with call stacks, CPU exceptions, crashes) on the next
/// launch after they happen, and metrics (launch time, scroll and animation
/// hitches) about once a day. Each payload is saved as its own JSON file in
/// Application Support/Diagnostics, newest `limit` kept. Nothing leaves the
/// device unless the owner shares the combined file.
final class PerformanceReports: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceReports()
    static let limit = 30

    private let queue = DispatchQueue(label: "fusionha.performance-reports", qos: .utility)
    private var started = false
    private static let clearedKey = "performanceReportsClearedAt"

    /// Subscribes once and saves what MetricKit already delivered this week.
    func start() {
        guard !started else { return }
        started = true
        MXMetricManager.shared.add(self)
        let manager = MXMetricManager.shared
        let past = manager.pastPayloads
        let pastDiagnostics = manager.pastDiagnosticPayloads
        queue.async {
            past.forEach { self.save($0.jsonRepresentation(), kind: "metrics", end: $0.timeStampEnd, begin: $0.timeStampBegin) }
            pastDiagnostics.forEach { self.save($0.jsonRepresentation(), kind: "diagnostics", end: $0.timeStampEnd, begin: $0.timeStampBegin) }
            self.prune()
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        queue.async {
            payloads.forEach { self.save($0.jsonRepresentation(), kind: "metrics", end: $0.timeStampEnd, begin: $0.timeStampBegin) }
            self.prune()
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        queue.async {
            payloads.forEach { self.save($0.jsonRepresentation(), kind: "diagnostics", end: $0.timeStampEnd, begin: $0.timeStampBegin) }
            self.prune()
        }
    }

    // MARK: Files

    static var folder: URL {
        URL.applicationSupportDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
    }

    /// The saved reports, newest first.
    static func files() -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
        return urls.filter { $0.pathExtension == "json" }
            .sorted { modified($0) > modified($1) }
    }

    static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// Deletes every saved report. Payloads MetricKit hands back again later
    /// (it keeps a week of them) are skipped unless they are newer than this.
    static func clear() {
        UserDefaults.standard.set(Date(), forKey: clearedKey)
        files().forEach { try? FileManager.default.removeItem(at: $0) }
    }

    /// Named by kind and time span, so a payload MetricKit hands over again
    /// (the past payloads on every launch) lands on the same file.
    private func save(_ json: Data, kind: String, end: Date, begin: Date) {
        if let cleared = UserDefaults.standard.object(forKey: Self.clearedKey) as? Date, end <= cleared { return }
        let name = "\(kind)-\(Int(end.timeIntervalSince1970))-\(Int(begin.timeIntervalSince1970)).json"
        let url = Self.folder.appending(path: name)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        try? json.write(to: url, options: .atomic)
    }

    private func prune() {
        Self.files().dropFirst(Self.limit).forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
