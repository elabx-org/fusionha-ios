import Foundation
import FusionhaKit

/// One timeline reload of the paged Downloads widget: its time budget, the
/// entry built so far (what a timed-out reload still shows) and its log, saved
/// to the extension's defaults at every stage so a killed reload is visible.
final class WidgetRun: @unchecked Sendable {
    /// WidgetKit allows a reload only a few seconds more than this.
    static let budget: TimeInterval = 8

    let deadline = WidgetDeadline(seconds: WidgetRun.budget)
    /// The reload before this one, read before this one overwrites it.
    let previous = WidgetPageStore.lastRun
    private let lock = NSLock()
    private var log: WidgetRunLog
    private var partial = DownloadsEntry(date: .now, total: 0, rows: [], signedIn: true, failed: true)
    private var closed = false

    init(page: WidgetPage?) {
        log = WidgetRunLog(stage: "auth", page: page?.rawValue ?? "-")
        WidgetPageStore.saveRun(log)
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

    /// Ends the run; later stages from abandoned work are ignored.
    func finish(timedOut: Bool) -> WidgetRunLog {
        update { log in
            if timedOut {
                log.outcome = .timedOut
                log.error = log.error ?? "budget \(Int(Self.budget))s"
            } else if log.outcome == .running {
                log.outcome = .ok
            }
        }
        return lock.withLock {
            closed = true
            return log
        }
    }

    private func update(_ change: (inout WidgetRunLog) -> Void) {
        let snapshot: WidgetRunLog? = lock.withLock {
            guard !closed else { return nil }
            change(&log)
            log.seconds = Date().timeIntervalSince(log.started)
            return log
        }
        if let snapshot { WidgetPageStore.saveRun(snapshot) }
    }
}
