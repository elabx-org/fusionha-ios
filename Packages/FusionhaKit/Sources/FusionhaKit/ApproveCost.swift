import Foundation

/// v2's Approve with changes (mock requests.js `approveSheet`): the line on
/// top saying what was asked, and the cost sentence under the form saying
/// what the approve will do with the choices as they stand ("Adds Burning
/// in HD-1080p, ~14.7 GB, leaving 488 GB free, and searches now. eafx is
/// told."). Sizes come from the request's triage, which estimates only the
/// versions asked for: a version switched on here has no estimate, so the
/// size and free space are left out rather than guessed.
public enum ApproveCost {
    /// "eafx asked for HD only. Change anything here before it is added."
    public static func askedLine(requester: String, asked: [QualityTier]) -> String {
        let who = TriageFacts.firstName(requester)
        let words = asked.map { $0 == .uhd ? "4K" : "HD" }
        let what = words.isEmpty ? "this" : DecisionPlan.list(words) + (words.count == 1 ? " only" : "")
        return "\(who) asked for \(what). Change anything here before it is added."
    }

    public static func sentence(title: String, tiers: [QualityTier], triage: RequestTriage?,
                                search: Bool, requester: String) -> String {
        guard !tiers.isEmpty else { return "Turn on a version to approve." }
        let who = TriageFacts.firstName(requester)
        let versions = (triage?.versions ?? []).filter { tiers.contains($0.tier) }
        let tracked = versions.count == tiers.count && versions.allSatisfy { $0.existing == true }
        var parts = ["\(tracked ? "Monitors" : "Adds") \(title) in \(DecisionPlan.list(tiers.map(\.rawValue)))"]
        if let bytes = size(tiers: tiers, versions: versions) {
            parts.append("~" + DetailText.bytes(bytes))
            if let free = triage.flatMap({ TriageFacts.tightestDisk($0.disks) })?.freeBytes {
                let after = free - bytes
                parts.append(after >= 0 ? "leaving \(DetailText.bytes(after)) free"
                                        : "more than the \(DetailText.bytes(free)) free")
            }
        }
        let head = parts.joined(separator: ", ")
        let tail = search ? (parts.count > 1 ? ", and searches now." : " and searches now.") : ". It doesn’t search yet."
        return head + tail + " \(who) is told."
    }

    /// The estimate for every chosen version, or nil when one has none.
    static func size(tiers: [QualityTier], versions: [RequestTriage.Version]) -> Double? {
        var total = 0.0
        for tier in tiers {
            guard let bytes = versions.first(where: { $0.tier == tier })?.estimateBytes else { return nil }
            total += bytes
        }
        return total > 0 ? total : nil
    }
}
