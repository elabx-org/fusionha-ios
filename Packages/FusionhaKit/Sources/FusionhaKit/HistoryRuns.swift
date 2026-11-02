import Foundation

/// Folds consecutive history events that share a key into one run
/// ("Numbering fixed · 5 episodes"). A nil key never folds.
public enum HistoryRuns {
    public static func runs<T>(_ items: [T], key: (T) -> String?) -> [[T]] {
        var out: [[T]] = []
        var lastKey: String?
        for item in items {
            let k = key(item)
            if let k, k == lastKey, !out.isEmpty {
                out[out.count - 1].append(item)
            } else {
                out.append([item])
            }
            lastKey = k
        }
        return out
    }

    /// Same event kind, same version, same minute. Grabs never fold (each keeps its Regrab).
    public static func key(eventType: String, editionId: Int?, date: Date?) -> String? {
        guard eventType != "GRABBED", let date else { return nil }
        return "\(eventType)|\(editionId ?? -1)|\(Int(date.timeIntervalSince1970 / 60))"
    }
}
