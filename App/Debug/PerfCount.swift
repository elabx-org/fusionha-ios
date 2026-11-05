import SwiftUI
import UIKit
import Darwin

extension Notification.Name {
    /// Switches ActivityView's tab (object: the ActivityTab raw value).
    static let perfActivityTab = Notification.Name("fusionha.perf.activityTab")
    /// Closes the open title the way its Close button does (`ShellDetailColumn`).
    static let perfCloseTitle = Notification.Name("fusionha.perf.closeTitle")
    /// The session script's finger on v2's split handle: object is [dx, velocity] (points, points/s).
    static let perfSeamDrag = Notification.Name("fusionha.perf.seamDrag")
}

/// Cheap counters for view-body evaluations and derived-data rebuilds.
enum PerfCount {
    #if DEBUG
    static let enabled = ProcessInfo.processInfo.environment["FUSIONHA_PERF"] != nil
    private static let lock = NSLock()
    nonisolated(unsafe) private static var counts: [String: Int] = [:]
    nonisolated(unsafe) private static var times: [String: Double] = [:]
    nonisolated(unsafe) private static var marks: [String: Double] = [:]

    /// The first time each mark was hit since the last call, then clears them.
    static func takeMarks() -> [String: Double] {
        lock.lock(); defer { marks = [:]; lock.unlock() }
        return marks
    }

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

    /// Records when `key` first happened (the v2 open script's timeline).
    @inline(__always)
    static func mark(_ key: String) {
        #if DEBUG
        guard enabled else { return }
        let now = CACurrentMediaTime()
        lock.lock(); if marks[key] == nil { marks[key] = now }; lock.unlock()
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

    /// Lets the perf script drag v2's split handle by dx and let go at a velocity. A no-op in Release.
    func perfSeamDragHook(_ drag: @escaping (Double, Double) -> Void) -> some View {
        #if DEBUG
        onReceive(NotificationCenter.default.publisher(for: .perfSeamDrag)) { note in
            if let v = note.object as? [Double], v.count == 2 { drag(v[0], v[1]) }
        }
        #else
        self
        #endif
    }

    /// Lets the perf script close the open title through `close`. A no-op in Release.
    func perfCloseTitleHook(_ close: @escaping () -> Void) -> some View {
        #if DEBUG
        onReceive(NotificationCenter.default.publisher(for: .perfCloseTitle)) { _ in close() }
        #else
        self
        #endif
    }
}
