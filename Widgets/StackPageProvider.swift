import Foundation
import WidgetKit
import FusionhaKit

/// The timeline of one single-view widget (`WidgetStack`): only that view's
/// data, with the Downloads widget's 7 s budget, 10 s watchdog and run journal,
/// and a Smart Stack relevance score on the entry.
struct StackPageProvider: TimelineProvider {
    let stack: WidgetStack

    func placeholder(in context: Context) -> DownloadsEntry { WidgetStackSamples.entry(stack) }

    func getSnapshot(in context: Context, completion: @escaping (DownloadsEntry) -> Void) {
        if context.isPreview { completion(WidgetStackSamples.entry(stack)); return }
        let stack = stack, family = context.family
        WidgetProviderRun.snapshot(kind: stack.kind, family: family, completion: completion,
                                   fallback: { Self.watchdogEntry($0, stack) },
                                   fetch: { await WidgetStackLoader.entry(stack, family: family, run: $0) })
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DownloadsEntry>) -> Void) {
        let stack = stack, family = context.family
        WidgetProviderRun.timeline(kind: stack.kind, family: family, completion: completion,
                                   fallback: { Self.watchdogEntry($0, stack) }) { run in
            let entry = await WidgetStackLoader.entry(stack, family: family, run: run)
            return Timeline(entries: [entry], policy: .after(Self.refresh(stack, after: entry)))
        }
    }

    /// Short only while downloads move or after a failed load; see `WidgetStack.refreshMinutes`.
    static func refresh(_ stack: WidgetStack, after entry: DownloadsEntry) -> Date {
        let failed = entry.failed || entry.pageError != nil
        let minutes = failed ? WidgetStack.retryMinutes : stack.refreshMinutes(active: !entry.idle)
        return .now.addingTimeInterval(minutes * 60)
    }

    /// The entry built so far, marked timed out, showing this widget's view.
    static func watchdogEntry(_ run: WidgetRun, _ stack: WidgetStack) -> DownloadsEntry {
        let log = WidgetProviderRun.watchdogLog(run)
        var entry = run.entry
        entry.page = stack.page
        entry.pages = [stack.page]
        if entry.pageError == nil { entry.pageError = "timed out" }
        entry.diagnostic = log.line
        entry.runId = run.id
        entry.relevanceScore = WidgetRelevance.low
        return entry
    }
}
