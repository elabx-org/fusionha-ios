import Foundation

/// A completion handler that runs once: the first of the real result and the
/// watchdog's fallback wins. The watchdog runs on a plain dispatch queue, not
/// the Swift concurrency pool, so it still fires when that pool is stuck.
final class WidgetOnce<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: ((Value) -> Void)?

    init(_ completion: @escaping (Value) -> Void) {
        self.completion = completion
    }

    /// True when this call delivered the value.
    @discardableResult
    func callAsFunction(_ value: Value) -> Bool {
        let handler = lock.withLock { () -> ((Value) -> Void)? in
            defer { completion = nil }
            return completion
        }
        handler?(value)
        return handler != nil
    }

    /// Delivers `fallback()` after `seconds` unless the real value came first.
    func watchdog(after seconds: TimeInterval, _ fallback: @escaping @Sendable () -> Value) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + seconds) { [self] in
            let pending = lock.withLock { completion != nil }
            if pending { self(fallback()) }
        }
    }
}
