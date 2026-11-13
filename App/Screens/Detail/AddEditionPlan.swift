import Foundation
import FusionhaKit

/// One version Add a version may create: a tier and an edition (nil = Standard).
struct AddEditionPair: Hashable {
    let tier: QualityTier
    let edition: String?

    var label: String { "\(tier.badgeLetters) · \(edition ?? "Standard")" }
}

/// What Add a version will do with the tiers and editions ticked (owner-
/// approved mock 2026-11-13): every tier × edition pair is its own version;
/// pairs already on the title are skipped by name, never sent.
struct AddEditionPlan {
    let pairs: [AddEditionPair]
    let fresh: [AddEditionPair]
    let skipped: [AddEditionPair]

    init(tiers: Set<QualityTier>, editions: [String?], existing: [DetailEdition]) {
        let have = Set(existing.map { Self.key($0.tier, $0.movieEdition) })
        var pairs: [AddEditionPair] = []
        for tier in QualityTier.ordered where tiers.contains(tier) {
            for edition in editions { pairs.append(AddEditionPair(tier: tier, edition: edition)) }
        }
        self.pairs = pairs
        fresh = pairs.filter { !have.contains(Self.key($0.tier, $0.edition)) }
        skipped = pairs.filter { have.contains(Self.key($0.tier, $0.edition)) }
    }

    /// Standard is nil or empty on the wire; names compare without case.
    static func key(_ tier: QualityTier, _ edition: String?) -> String {
        let name = (edition ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        return "\(tier.rawValue)|\(name == "standard" ? "" : name)"
    }

    /// "HD · Encore, 4K · Encore", or "Nothing new".
    var freshText: String {
        fresh.isEmpty ? "Nothing new" : fresh.map(\.label).joined(separator: ", ")
    }

    /// "HD · Standard is already here", or nil.
    var skippedText: String? {
        guard !skipped.isEmpty else { return nil }
        return skipped.map(\.label).joined(separator: ", ") + (skipped.count == 1 ? " is already here" : " are already here")
    }

    /// The toast after adding.
    static func outcome(added: [AddEditionPair], skipped: Int, searching: Bool) -> String {
        var text = added.count == 1 ? "Added \(added[0].label)" : "Added \(added.count) versions"
        if searching { text += " · searching" }
        if skipped > 0 { text += " · \(skipped) already here" }
        return text
    }
}
