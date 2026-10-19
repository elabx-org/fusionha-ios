import SwiftUI
import FusionhaKit

/// The empty queue's reads (web `idle-data.ts`), only while the queue is empty:
/// the idle summary (every minute, plus once a due run has had time to finish),
/// the shared calendar feed for yesterday → +4 days (every 10 minutes), the
/// first page of imports (every minute) and the `voice_playful` setting.
@MainActor
@Observable
final class QueueIdleFeed {
    private(set) var summary: IdleSummary?
    private(set) var summaryFailed = false
    private(set) var calendar: [CalendarEntry]?
    private(set) var calendarFailed = false
    private(set) var imports: [HistoryEntry]?
    private(set) var importsFailed = false
    private(set) var playful = true

    func run(_ client: APIClient?) async {
        guard let client else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.summaryLoop(client) }
            group.addTask { await self.calendarLoop(client) }
            group.addTask { await self.importsLoop(client) }
            group.addTask { await self.loadSettings(client) }
        }
    }

    private func summaryLoop(_ client: APIClient) async {
        while !Task.isCancelled {
            do {
                let next = try await client.idleSummary()
                if next != summary { summary = next }
                summaryFailed = false
            } catch is CancellationError {
                return
            } catch {
                summaryFailed = summary == nil
            }
            let wait = summary.flatMap { IdleTime.refetchDelay($0.tasks, now: Date()) } ?? 60
            try? await Task.sleep(for: .seconds(min(60, wait)))
        }
    }

    private func calendarLoop(_ client: APIClient) async {
        while !Task.isCancelled {
            let range = IdleTime.comingUpRange(now: Date())
            do {
                let next = try await client.calendar(startISO: range.start, endISO: range.end)
                if next != calendar { calendar = next }
                calendarFailed = false
            } catch is CancellationError {
                return
            } catch {
                calendarFailed = calendar == nil
            }
            try? await Task.sleep(for: .seconds(600))
        }
    }

    private func importsLoop(_ client: APIClient) async {
        while !Task.isCancelled {
            do {
                let next = try await client.recentImports(pageSize: IdleRecent.pageSize).items
                if next != imports { imports = next }
                importsFailed = false
            } catch is CancellationError {
                return
            } catch {
                importsFailed = imports == nil
            }
            try? await Task.sleep(for: .seconds(60))
        }
    }

    private func loadSettings(_ client: APIClient) async {
        if let settings = try? await client.activitySettings() { playful = settings.voicePlayful ?? true }
    }
}
