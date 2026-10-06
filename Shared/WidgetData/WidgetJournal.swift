import Foundation
import WidgetKit
import FusionhaKit

/// The widget extension's run journal: the last few timeline calls of every
/// widget, saved to the shared keychain at each stage (UserDefaults aren't
/// shared on a build signed without the App Group). The app reads it for the
/// avatar menu's Widget diagnostics. Every call is a few small keychain reads
/// and writes, serialised within the process.
enum WidgetJournal {
    private static let account = "widget-runs"
    private static let lock = NSLock()
    /// Runs whose entry this process already marked drawn.
    nonisolated(unsafe) private static var drawn: Set<String> = []

    static func all() -> [WidgetRunRecord] {
        lock.withLock { WidgetRunJournal.decode(SharedKeychain.read(account)) }
    }

    /// Saves `record`; returns the journal as it was before (for the previous run).
    @discardableResult
    static func save(_ record: WidgetRunRecord) -> [WidgetRunRecord] {
        lock.withLock {
            let before = WidgetRunJournal.decode(SharedKeychain.read(account))
            if let data = WidgetRunJournal.encode(WidgetRunJournal.upserting(record, into: before)) {
                SharedKeychain.write(data, account)
            }
            return before
        }
    }

    /// Marks a run's entry drawn, once per run (the entry view's body can run
    /// several times).
    static func markDrawn(_ id: String?) {
        guard let id, !id.isEmpty else { return }
        let first = lock.withLock { drawn.insert(id).inserted }
        guard first else { return }
        lock.withLock {
            var records = WidgetRunJournal.decode(SharedKeychain.read(account))
            guard let index = records.firstIndex(where: { $0.id == id }) else { return }
            records[index].rendered = true
            if let data = WidgetRunJournal.encode(records) { SharedKeychain.write(data, account) }
        }
    }

    static func clear() {
        lock.withLock { SharedKeychain.delete(account) }
    }

    /// `small`, `medium`, `large`, `extraLarge`, `accessory…`.
    static func name(_ family: WidgetFamily) -> String {
        switch family {
        case .systemSmall: return "small"
        case .systemMedium: return "medium"
        case .systemLarge: return "large"
        case .systemExtraLarge: return "extraLarge"
        default: return "\(family)"
        }
    }
}
