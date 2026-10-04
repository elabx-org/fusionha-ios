import Foundation

// Setup progress (`GET /api/v1/library/setups`, lib/api/setup-progress.ts): the
// background work fusionha runs right after a title is added. Hand-written to
// mirror the backend's SetupRead / SetupListRead.

public enum SetupStepStatus: String, Decodable, Sendable {
    case pending, running, done, skipped, failed, other

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SetupStepStatus(rawValue: raw) ?? .other
    }

    /// `setupStepFinished`: moved out of pending/running.
    public var finished: Bool { self == .done || self == .skipped || self == .failed }
}

public struct SetupStep: Decodable, Sendable, Hashable {
    /// `added` | `tree` | `airtimes` | `numbering` | `anime_ids` | `search`.
    public let key: String
    public let label: String
    public let source: String?
    public let status: SetupStepStatus
    public let detail: String?
}

public struct SetupGrab: Decodable, Sendable, Hashable {
    public let quality: String?
    /// "S17·E1", "Season 17", or nil for a movie.
    public let target: String?
    public let releaseTitle: String?
}

/// The first search's outcome for one version. Decodes both the 0.4.122+
/// keys (`version_id`, `edition`) and the older ones (`edition_id`, `movie_edition`).
public struct SetupVersionResult: Decodable, Sendable, Hashable {
    public let versionId: Int?
    public let tier: QualityTier
    public let edition: String?
    public let grabs: [SetupGrab]
    public let grabCount: Int

    private enum CodingKeys: String, CodingKey {
        case versionId, editionId, tier, edition, movieEdition, grabs, grabCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decodeIfPresent(Int.self, forKey: .versionId)
        versionId = try version ?? c.decodeIfPresent(Int.self, forKey: .editionId)
        tier = try c.decode(QualityTier.self, forKey: .tier)
        let cut = try c.decodeIfPresent(String.self, forKey: .edition)
        edition = try cut ?? c.decodeIfPresent(String.self, forKey: .movieEdition)
        grabs = try c.decodeIfPresent([SetupGrab].self, forKey: .grabs) ?? []
        grabCount = try c.decodeIfPresent(Int.self, forKey: .grabCount) ?? grabs.count
    }

    /// `versionLabel`: "Black & White · HD·1080p", or just the tier label.
    public var label: String {
        guard let edition, !edition.isEmpty else { return tier.chipLabel }
        return "\(edition) · \(tier.chipLabel)"
    }
}

public struct TitleSetup: Decodable, Sendable, Hashable, Identifiable {
    public let itemId: Int
    public let title: String
    public let posterUrl: String?
    public let steps: [SetupStep]
    public let result: [SetupVersionResult]?
    public let startedAt: String?
    public let finishedAt: String?

    public var id: Int { itemId }
    public var isActive: Bool { finishedAt == nil }
}

public struct TitleSetupList: Decodable, Sendable, Hashable {
    public let setups: [TitleSetup]
    public let nextRssAt: String?

    public init(setups: [TitleSetup] = [], nextRssAt: String? = nil) {
        self.setups = setups
        self.nextRssAt = nextRssAt
    }

    private enum CodingKeys: String, CodingKey { case setups, nextRssAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        setups = try c.decodeIfPresent([TitleSetup].self, forKey: .setups) ?? []
        nextRssAt = try c.decodeIfPresent(String.self, forKey: .nextRssAt)
    }

    /// `anySetupActive`.
    public var anyActive: Bool { setups.contains(where: \.isActive) }

    /// `setupPollInterval`: 2s while anything is setting up, else 20s.
    public var pollInterval: TimeInterval { anyActive ? 2 : 20 }
}

// MARK: - Formatting (components/shell/setup-progress-format.ts)

public struct SetupResultLine: Sendable, Hashable {
    public enum Tone: Sendable { case ok, wait }
    public let tone: Tone
    public let text: String
}

extension TitleSetup {
    public var doneCount: Int { steps.filter { $0.status.finished }.count }

    /// Ring fraction (0–1). A setup with no steps reads full.
    public var progressFraction: Double {
        steps.isEmpty ? 1 : Double(doneCount) / Double(steps.count)
    }

    /// `setupNowLabel`.
    public var nowLabel: String {
        if finishedAt != nil {
            guard let result, !result.isEmpty else { return "Ready" }
            let total = result.reduce(0) { $0 + $1.grabCount }
            return total > 0 ? "Ready · \(total) grabbed" : "Ready · nothing yet"
        }
        if let running = steps.first(where: { $0.status == .running }) { return "\(running.label)…" }
        return steps.contains(where: { $0.status != .pending }) ? "Working…" : "Adding…"
    }

    /// `setupResultLine`: nil until the search step's result is in.
    public func resultLine(nextRssAt: String?, now: Date = Date()) -> SetupResultLine? {
        guard finishedAt != nil, let result, !result.isEmpty else { return nil }
        let multi = result.count > 1
        let sentences = result.map { r -> String in
            if r.grabCount == 0 { return multi ? "\(r.label): nothing yet" : "Nothing found yet" }
            let first = r.grabs.first
            let quality = first?.quality ?? "a release"
            let target = first?.target.map { " for \($0)" } ?? ""
            let extra = r.grabCount > 1 ? " (+\(r.grabCount - 1) more)" : ""
            return multi ? "\(r.label): grabbed \(quality)\(target)\(extra)" : "Grabbed \(quality)\(target)\(extra)"
        }
        if result.contains(where: { $0.grabCount > 0 }) {
            return SetupResultLine(tone: .ok, text: sentences.joined(separator: ". ") + ".")
        }
        let when: String
        if let next = DetailText.instant(nextRssAt) {
            let minutes = max(1, Int((next.timeIntervalSince(now) / 60).rounded()))
            when = " fusionha checks again with every RSS sync (next in \(minutes) min)."
        } else {
            when = " fusionha checks again on the next RSS sync."
        }
        return SetupResultLine(tone: .wait, text: sentences.joined(separator: ". ") + "." + when)
    }

    /// "Setting up <title>" (one) / "Setting up N titles" (stacked).
    public static func cardTitle(_ setups: [TitleSetup]) -> String {
        setups.count <= 1 ? "Setting up \(setups.first?.title ?? "")" : "Setting up \(setups.count) titles"
    }
}
