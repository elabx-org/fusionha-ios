import SwiftUI
import UIKit
import Darwin

extension Notification.Name {
    /// Switches ActivityView's tab (object: the ActivityTab raw value).
    static let perfActivityTab = Notification.Name("fusionha.perf.activityTab")
}

/// Cheap counters for view-body evaluations and derived-data rebuilds.
enum PerfCount {
    #if DEBUG
    static let enabled = ProcessInfo.processInfo.environment["FUSIONHA_PERF"] != nil
    private static let lock = NSLock()
    nonisolated(unsafe) private static var counts: [String: Int] = [:]
    nonisolated(unsafe) private static var times: [String: Double] = [:]

    static func snapshot() -> (counts: [String: Int], times: [String: Double]) {
        lock.lock(); defer { lock.unlock() }
        return (counts, times)
    }
    #endif

    @inline(__always)
    static func hit(_ key: String) {
        #if DEBUG
        guard enabled else { return }
        lock.lock(); counts[key, default: 0] += 1; lock.unlock()
        #endif
    }

    @inline(__always)
    static func time<T>(_ key: String, _ body: () -> T) -> T {
        #if DEBUG
        guard enabled else { return body() }
        let start = CACurrentMediaTime()
        let result = body()
        let elapsed = CACurrentMediaTime() - start
        lock.lock(); counts[key, default: 0] += 1; times[key, default: 0] += elapsed; lock.unlock()
        return result
        #else
        return body()
        #endif
    }
}

extension View {
    /// Lets the perf script switch ActivityView's tab. A no-op in Release.
    func perfActivityTabHook(_ tab: Binding<ActivityTab>) -> some View {
        #if DEBUG
        onReceive(NotificationCenter.default.publisher(for: .perfActivityTab)) { note in
            if let raw = note.object as? String, let value = ActivityTab(rawValue: raw) { tab.wrappedValue = value }
        }
        #else
        self
        #endif
    }
}
