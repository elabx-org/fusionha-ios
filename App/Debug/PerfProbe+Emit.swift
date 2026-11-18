import Foundation

#if DEBUG
extension PerfProbe {
    func emit(_ object: [String: Any]) {
        #if arch(arm64)
        // The last phase's stacks are written off the main thread: before
        // "done" (the scripts stop reading there), wait for them.
        if object["event"] as? String == "done" { MainSampler.shared.drain() }
        #endif
        Self.write(object)
    }

    /// One PERF line on stderr; from any thread.
    nonisolated static func write(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
        FileHandle.standardError.write(Data("PERF ".utf8) + data + Data("\n".utf8))
    }
}
#endif
