import Foundation

/// The queue card's ambient wash status (web `status-wash.ts` `WashStatus`),
/// ordered most urgent first: a group washes as its most urgent member
/// (`group-model.ts` `groupWash`: failed > attention > working > queued).
public enum QueueWashStatus: Int, CaseIterable, Sendable, Comparable {
    case failed, attention, working, queued

    public static func < (a: QueueWashStatus, b: QueueWashStatus) -> Bool { a.rawValue < b.rawValue }

    /// The most urgent of `statuses`; `working` when there are none.
    public static func mostUrgent<S: Sequence>(_ statuses: S) -> QueueWashStatus where S.Element == QueueWashStatus {
        statuses.min() ?? .working
    }
}

/// The one toast after a group's "Remove all" (web `use-remove-all.ts`).
public enum QueueRemoveAllCopy {
    public static func message(total: Int, failedNames: [String], blocklist: Bool) -> (text: String, isError: Bool) {
        let noun = { (n: Int) in "download\(n == 1 ? "" : "s")" }
        if failedNames.isEmpty {
            return (blocklist ? "Blocklisted and removed \(total) \(noun(total))"
                              : "Removed \(total) \(noun(total)) from the queue", false)
        }
        if failedNames.count == total {
            return ("Could not remove \(total == 1 ? "the download" : "any of the \(total) downloads"). Try again.", true)
        }
        let names = failedNames.joined(separator: ", ")
        return ("Removed \(total - failedNames.count) of \(total) \(noun(total)). Could not remove \(names); they are still in the queue. Try again.", true)
    }

    /// "S06E04" from "S06E04 · Niagara (1)"; nil without an episode label.
    public static func stripLabel(_ episodeLabel: String?) -> String? {
        let label = episodeLabel?.components(separatedBy: " · ").first?.trimmingCharacters(in: .whitespaces)
        return label?.isEmpty == false ? label : nil
    }
}
