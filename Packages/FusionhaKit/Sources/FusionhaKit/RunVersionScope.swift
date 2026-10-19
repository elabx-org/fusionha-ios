import Foundation

/// The detail Searches tab's version scope (runs.ts `useVersionScopedRuns`):
/// with one version focused, a run shows only when one of its candidates
/// belongs to that version.
public enum RunVersionScope {
    /// A candidate with a version id must match it; one without falls back to
    /// its quality's tier (2160 → UHD, else HD); with neither known it counts.
    public static func candidateInScope(candidateVersionId: Int?, quality: String?,
                                        versionId: Int, tier: QualityTier?) -> Bool {
        if let candidateVersionId { return candidateVersionId == versionId }
        guard let tier, let quality else { return true }
        let candidateTier: QualityTier = quality.range(of: "2160", options: .caseInsensitive) != nil ? .uhd : .hd
        return candidateTier == tier
    }

    public static func runInScope(_ detail: CommandRunDetail, versionId: Int, tier: QualityTier?) -> Bool {
        detail.candidates.contains {
            candidateInScope(candidateVersionId: $0.versionId, quality: $0.quality, versionId: versionId, tier: tier)
        }
    }
}
