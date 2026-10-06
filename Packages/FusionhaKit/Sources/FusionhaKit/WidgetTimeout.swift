import Foundation

// Time limits for the widget extension: WidgetKit gives a timeline reload a few
// seconds, so every fetch runs against a deadline and the reload always ends
// with an entry, partial if it has to be.

/// A widget fetch that ran past its time slice.
public struct WidgetTimedOut: Error, Equatable, Sendable {
    public let seconds: TimeInterval

    public init(seconds: TimeInterval) {
        self.seconds = seconds
    }
}

/// Runs `operation` for at most `seconds`, then throws `WidgetTimedOut`. It
/// returns as soon as either side finishes, even when the operation ignores
/// cancellation: the operation is cancelled and left to wind down on its own.
public func withTimeout<T: Sendable>(
    seconds: TimeInterval, _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let gate = TimeoutGate<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            gate.install(continuation)
            let work = Task {
                do { gate.finish(.success(try await operation())) } catch { gate.finish(.failure(error)) }
            }
            let timer = Task {
                try? await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
                gate.finish(.failure(WidgetTimedOut(seconds: seconds)))
            }
            gate.onFinish {
                work.cancel()
                timer.cancel()
            }
        }
    } onCancel: {
        gate.finish(.failure(CancellationError()))
    }
}

/// Resumes its continuation once, with whichever result arrives first.
private final class TimeoutGate<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var cleanup: (() -> Void)?
    private var done = false

    func install(_ continuation: CheckedContinuation<T, Error>) {
        lock.withLock { self.continuation = continuation }
    }

    /// Runs `body` when the gate closes (now, if it already has).
    func onFinish(_ body: @escaping () -> Void) {
        let runNow = lock.withLock { () -> Bool in
            if done { return true }
            cleanup = body
            return false
        }
        if runNow { body() }
    }

    func finish(_ result: Result<T, Error>) {
        let (continuation, cleanup) = lock.withLock { () -> (CheckedContinuation<T, Error>?, (() -> Void)?) in
            guard !done else { return (nil, nil) }
            done = true
            defer { self.continuation = nil; self.cleanup = nil }
            return (self.continuation, self.cleanup)
        }
        cleanup?()
        continuation?.resume(with: result)
    }
}

/// The end of a timeline reload's time budget, sliced up between its fetches.
public struct WidgetDeadline: Sendable {
    public let end: Date

    public init(seconds: TimeInterval, from now: Date = Date()) {
        end = now.addingTimeInterval(seconds)
    }

    public func remaining(now: Date = Date()) -> TimeInterval {
        max(end.timeIntervalSince(now), 0)
    }

    /// The time one call may take: at most `cap`, leaving `reserve` for what
    /// follows, and never less than a quarter second.
    public func slice(_ cap: TimeInterval, reserve: TimeInterval = 0, now: Date = Date()) -> TimeInterval {
        max(min(cap, remaining(now: now) - reserve), 0.25)
    }
}

/// `transform` over `items` with at most `maxConcurrent` running at once, in
/// input order. Keeps a widget's poster and title fetches from all firing together.
public func concurrentMap<T: Sendable, R: Sendable>(
    _ items: [T], maxConcurrent: Int, _ transform: @escaping @Sendable (T) async -> R
) async -> [R] {
    await withTaskGroup(of: (Int, R).self) { group in
        var results = [R?](repeating: nil, count: items.count)
        var next = 0
        while next < items.count {
            if next >= max(maxConcurrent, 1), let done = await group.next() {
                results[done.0] = done.1
            }
            let index = next, item = items[index]
            group.addTask { (index, await transform(item)) }
            next += 1
        }
        while let done = await group.next() { results[done.0] = done.1 }
        return results.compactMap { $0 }
    }
}
