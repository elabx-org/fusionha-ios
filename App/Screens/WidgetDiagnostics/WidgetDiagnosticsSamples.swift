#if DEBUG
import Foundation
import FusionhaKit

/// CI screenshots only (`FUSIONHA_SCREENSHOT_WIDGET_DIAG=sample`): a journal
/// like a stuck Downloads widget leaves it, written through the real keychain
/// path so the sheet reads it back as it would on a phone.
enum WidgetDiagnosticsSamples {
    static func seed() {
        WidgetJournal.clear()
        let samples = [
            record("Downloads", "medium", stage: "page", page: "upnext", outcome: .running, ago: 190, seconds: 2.1),
            record("UpNext", "medium", stage: "calendar", page: "-", outcome: .ok, ago: 160, seconds: 1.4, drawn: true),
            record("RecentlyAdded", "large", stage: "history", page: "-", outcome: .failed, ago: 120,
                   seconds: 5.2, error: "HTTP 502", drawn: true),
            record("Downloads", "small", stage: "queue", page: "-", outcome: .ok, ago: 60, seconds: 0.9, drawn: true),
            record("Downloads", "medium", stage: "page", page: "library", outcome: .timedOut, ago: 20,
                   seconds: 10, error: "watchdog 10s"),
        ]
        for sample in samples { WidgetJournal.save(sample) }
    }

    private static func record(_ kind: String, _ family: String, stage: String, page: String,
                               outcome: WidgetRunLog.Outcome, ago: TimeInterval, seconds: Double,
                               error: String? = nil, drawn: Bool = false) -> WidgetRunRecord {
        let log = WidgetRunLog(stage: stage, page: page, outcome: outcome, error: error,
                               started: Date().addingTimeInterval(-ago), seconds: seconds)
        return WidgetRunRecord(kind: kind, family: family, log: log, rendered: drawn)
    }
}
#endif
