import Foundation

// The per-candidate breakdown behind a decision-trail row (web
// `routes/tasks/trail-model.ts`, #163): the profile thresholds a candidate was
// judged against and the decision chain built from real signals only.

/// The thresholds of the profile a candidate was judged against (from its edition).
public struct TrailProfile: Sendable, Hashable {
    public let id: Int
    /// `min_format_score`.
    public let floor: Int
    /// `cutoff_format_score` (upgrade-until); nil = none.
    public let ceiling: Int?
    public let cutoffQuality: String
    public let upgradeAllowed: Bool
    public let allowed: [String]
    /// The title's ISO 639-1 original language, for the CF tester fallback.
    public let originalLanguage: String?

    public init(id: Int, floor: Int, ceiling: Int?, cutoffQuality: String, upgradeAllowed: Bool,
                allowed: [String], originalLanguage: String? = nil) {
        self.id = id
        self.floor = floor
        self.ceiling = ceiling
        self.cutoffQuality = cutoffQuality
        self.upgradeAllowed = upgradeAllowed
        self.allowed = allowed
        self.originalLanguage = originalLanguage
    }

    public init(_ record: QualityProfileRecord, originalLanguage: String? = nil) {
        self.init(id: record.id, floor: record.minFormatScore, ceiling: record.cutoffFormatScore,
                  cutoffQuality: record.cutoff, upgradeAllowed: record.upgradeAllowed,
                  allowed: record.allowedQualities, originalLanguage: originalLanguage)
    }
}

public enum TrailModel {
    public struct ChainStep: Sendable, Hashable, Identifiable {
        public enum State: Sendable { case ok, up, no, info }
        public let key: String
        public let text: String
        public let state: State
        public var id: String { key }

        /// ✓ met · ↑ upgradable · ✕ not met · `·` info.
        public var mark: String {
            switch state {
            case .ok: return "✓"
            case .up: return "↑"
            case .no: return "✕"
            case .info: return "·"
            }
        }
    }

    /// 2160p qualities are the UHD·4K tier; everything else is HD.
    public static func tier(forQuality quality: String?) -> QualityTier {
        quality?.range(of: "2160", options: .caseInsensitive) != nil ? .uhd : .hd
    }

    /// A signed score, always with an explicit sign (`+5000` / `-100`).
    public static func signed(_ score: Int) -> String { score > 0 ? "+\(score)" : "\(score)" }

    /// "Grabbed" / "Upgraded" / "Rejected" / "Skipped".
    public static func verdictLabel(_ action: String) -> String {
        switch action {
        case "GRAB": return "Grabbed"
        case "UPGRADE": return "Upgraded"
        case "REJECT": return "Rejected"
        default: return "Skipped"
        }
    }

    /// The decision chain: a grab reads its positive path, a reject or skip why it lost.
    public static func chain(_ c: RunCandidate, profile: TrailProfile?, considered: Int) -> [ChainStep] {
        var steps: [ChainStep] = []
        let grab = c.action == "GRAB" || c.action == "UPGRADE"
        let total = c.cfScore ?? 0
        if let profile, let quality = c.quality {
            let label = DetailText.quality(quality)
            let allowed = profile.allowed.contains(quality)
            steps.append(ChainStep(key: "quality",
                                   text: allowed ? "\(label) is allowed in the profile ladder"
                                                 : "\(label) is not in the profile ladder",
                                   state: allowed ? .ok : .no))
        }
        if grab && c.reason.range(of: "no file", options: .caseInsensitive) != nil {
            steps.append(ChainStep(key: "first", text: "First grab — no file for this version to beat", state: .ok))
        }
        if let profile {
            let clears = total >= profile.floor
            steps.append(ChainStep(key: "floor",
                                   text: clears ? "Clears the score floor (\(total) ≥ \(profile.floor) minimum)"
                                                : "Below the score floor (\(total) < \(profile.floor) minimum)",
                                   state: clears ? .ok : .no))
        }
        if grab && considered > 1 {
            steps.append(ChainStep(key: "best", text: "Best of \(considered) releases considered", state: .ok))
        }
        if !grab {
            steps.append(ChainStep(key: "lost", text: c.reason.isEmpty ? "Passed over" : c.reason, state: .no))
        }
        if grab, let profile, profile.upgradeAllowed, let ceiling = profile.ceiling,
           total < ceiling || c.quality != profile.cutoffQuality {
            let cutoff = DetailText.quality(profile.cutoffQuality)
            steps.append(ChainStep(key: "upgrade",
                                   text: "Not yet at cutoff — still upgradable to \(cutoff) or a higher score (up to \(ceiling))",
                                   state: .up))
        }
        return steps
    }

    /// The upgrade-until track: the total's and the floor's place on 0…ceiling, clamped.
    public static func track(total: Int, profile: TrailProfile) -> (totalPct: Int, floorPct: Int)? {
        guard let ceiling = profile.ceiling, ceiling > 0 else { return nil }
        let t = min(100, Int((Double(max(0, total)) / Double(ceiling) * 100).rounded()))
        let f = min(100, max(0, Int((Double(profile.floor) / Double(ceiling) * 100).rounded())))
        return (t, f)
    }
}
