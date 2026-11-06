import Foundation

/// The v2 decision card's plan sentence (mock requests.js `plan`): what
/// Approve does in one line, from the request's triage, then what the two
/// overrides do. The Inbox's Approve always searches (`search: true`).
public enum DecisionPlan {
    public struct Sentence: Equatable, Sendable {
        /// "Approve adds Burning in HD-1080p to /movies and searches now."
        public let approve: String
        /// "Not yet tells Sam … Decline asks for a reason.", nil when the
        /// viewer can't decide this one.
        public let overrides: String?
        /// Approve can't go ahead as it stands (no Add default, or own request).
        public let blocked: Bool
    }

    public static func sentence(title: String, tiers: [QualityTier], triage: RequestTriage?,
                                requester: String, own: Bool) -> Sentence {
        let who = TriageFacts.firstName(requester)
        let overrides = own ? nil
            : "Not yet tells \(who) it isn’t available yet and keeps it on their list. Decline asks for a reason."
        if own { return Sentence(approve: TriageFacts.ownRequestNote, overrides: nil, blocked: true) }
        guard let triage else {
            return Sentence(approve: "Checking what Approve will do…", overrides: overrides, blocked: true)
        }
        let asked = tiers.isEmpty ? triage.versions.map(\.tier) : tiers
        let versions = triage.versions.filter { asked.contains($0.tier) }
        let tierText = list(asked.map(\.rawValue))
        if let missing = versions.first(where: { !$0.configured }) {
            return Sentence(approve: "Approve needs an Add default for \(missing.tier.rawValue) first. Use Adjust to pick a root folder and profile.",
                            overrides: overrides, blocked: true)
        }
        var roots: [String] = []
        for path in versions.compactMap(\.rootPath) where !path.isEmpty && !roots.contains(path) { roots.append(path) }
        let allTracked = !versions.isEmpty && versions.allSatisfy { $0.existing == true }
        let verb = allTracked ? "monitors" : "adds"
        let place = roots.isEmpty ? "" : (allTracked ? " in " : " to ") + list(roots)
        return Sentence(approve: "Approve \(verb) \(title) in \(tierText)\(place) and searches now.",
                        overrides: overrides, blocked: false)
    }

    /// "a", "a and b", "a, b and c".
    static func list(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return ""
        case 1: return parts[0]
        default: return parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
    }
}
