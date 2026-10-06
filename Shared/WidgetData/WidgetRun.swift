import Foundation
import WidgetKit
import FusionhaKit

/// One timeline reload of a widget: its time budget, the entry built so far
/// (what a timed-out reload still shows) and its journal record, saved at
/// every stage so a killed reload is left `running` for the app to see.
final class WidgetRun: @unchecked Sendable {
    /// Every fetch fits in this; the provider's watchdog fires a little later.
    static let budget: TimeInterval = 7
    /// The provider hands WidgetKit an entry by then, whatever is still running.
    static let watchdog: TimeInterval = 10

    let deadline = WidgetDeadline(seconds: WidgetRun.budget)
    /// The reload before this one of the same widget and size.
    let previous: WidgetRunLog?
    let id: String
    private let lock = NSLock()
    private var record: WidgetRunRecord
    private var partial = DownloadsEntry(date: .now, total: 0, rows: [], signedIn: true, failed: true)
    private var closed = false

    init(kind: String, family: WidgetFamily, call: String = "timeline", page: WidgetPage? = nil) {
        let family = WidgetJournal.name(family)
        let first = WidgetRunRecord(kind: kind, family: family, call: call,
                                    log: WidgetRunLog(stage: "start", page: page?.rawValue ?? "-"))
        let before = WidgetJournal.save(first)
        record = first
        id = first.id
        previous = WidgetRunJournal.previous(kind: kind, family: family, before: first.id, in: before)?.log
    }

    /// The entry so far.
    var entry: DownloadsEntry { lock.withLock { partial } }

    func keep(_ entry: DownloadsEntry) {
        lock.withLock { partial = entry }
    }

    func stage(_ name: String, page: WidgetPage? = nil) {
        update { log in
            log.stage = name
            if let page { log.page = page.rawValue }
        }
    }

    /// Records the first error; the reload carries on with partial data.
    func fail(_ error: Error) {
        update { log in
            guard log.outcome == .running else { return }
            log.outcome = .failed
            log.error = WidgetRunLog.describe(error)
        }
    }

    /// Ends the run (the first call wins); later stages from abandoned work
    /// are ignored. `timedOut` with a `reason` names what ran out.
    @discardableResult
    func finish(timedOut: Bool, reason: String? = nil) -> WidgetRunLog {
        update(closing: true) { log in
            if timedOut {
                log.outcome = .timedOut
                log.error = reason ?? log.error ?? "budget \(Int(Self.budget))s"
            } else if log.outcome == .running {
                log.outcome = .ok
            }
        }
        return lock.withLock { record.log }
    }

    private func update(closing: Bool = false, _ change: (inout WidgetRunLog) -> Void) {
        // Saved under the lock so a late stage can never overwrite the finish.
        lock.withLock {
            guard !closed else { return }
            change(&record.log)
            record.log.seconds = Date().timeIntervalSince(record.log.started)
            if closing { closed = true }
            WidgetJournal.save(record)
        }
    }
}
