import Foundation
import WidgetKit
import FusionhaKit

/// The providers' shared call pattern: every snapshot and timeline call hands
/// WidgetKit an entry within `WidgetRun.watchdog` seconds, whatever the
/// network or the keychain does, and each call is a journalled `WidgetRun`
/// (the app's Widget diagnostics read it).
enum WidgetProviderRun {
    static func snapshot<Entry>(kind: String, family: WidgetFamily, completion: @escaping (Entry) -> Void,
                                fallback: @escaping (WidgetRun) -> Entry,
                                fetch: @escaping (WidgetRun) async -> Entry) {
        let once = WidgetOnce(completion)
        let run = WidgetRun(kind: kind, family: family, call: "snapshot")
        once.watchdog(after: WidgetRun.watchdog) { fallback(run) }
        Task { once(await fetch(run)) }
    }

    /// `fetch` builds the timeline; past the watchdog, `fallback`'s entry is
    /// shown and the widget retries in `WidgetStack.retryMinutes`.
    static func timeline<Entry: TimelineEntry>(kind: String, family: WidgetFamily,
                                               completion: @escaping (Timeline<Entry>) -> Void,
                                               fallback: @escaping (WidgetRun) -> Entry,
                                               fetch: @escaping (WidgetRun) async -> Timeline<Entry>) {
        let once = WidgetOnce(completion)
        let run = WidgetRun(kind: kind, family: family)
        once.watchdog(after: WidgetRun.watchdog) {
            Timeline(entries: [fallback(run)], policy: .after(.now.addingTimeInterval(WidgetStack.retryMinutes * 60)))
        }
        Task { once(await fetch(run)) }
    }

    /// Ends a run the watchdog cut short; returns its journal log.
    @discardableResult
    static func watchdogLog(_ run: WidgetRun) -> WidgetRunLog {
        run.finish(timedOut: true, reason: "watchdog \(Int(WidgetRun.watchdog))s")
    }

    /// `entry` repeated at each relevance step (same data, rising or fading
    /// score), so Smart Stack ranking changes without spending a reload.
    static func steps<Entry>(_ steps: [WidgetStackRelevance.Step], _ make: (Date, Float) -> Entry) -> [Entry] {
        steps.map { make($0.date, $0.score) }
    }
}
