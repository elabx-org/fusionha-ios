import Foundation

// The Activity queue card fields fusionha 0.4.189 added to `QueueRead`
// (`api/schemas_queue_card.py`): the decypharr stage plan, a pack's compact
// done/current/waiting summary and its paged episode list, the idle pipeline
// line, and the release facts parsed from the release name. Everything is
// optional, so older servers keep decoding.

/// One stage on a job's decypharr rail.
public struct QueueStage: Decodable, Sendable, Hashable {
    /// queued, parsing, downloading, processed, linking, caching, probing,
    /// validating or complete.
    public let key: String
    /// False when this install skips the stage (draw it greyed).
    public let runs: Bool
}

/// The server's stage plan for one job. When present it is the truth; the
/// client's `QueueRules` is the fallback for servers before 0.4.189.
public struct QueueStages: Decodable, Sendable, Hashable {
    /// `phase` (a decypharr symlink/stream job: stage rail + ring, no MB/s) or
    /// `bytes` (a real download: percent, time left, MB/s).
    public let mode: String
    /// `usenet` or `debrid`; nil for a non-decypharr job.
    public let route: String?
    public let steps: [QueueStage]?
    /// The stage the job is at; for a failed job, the furthest it reached.
    public let current: String?
    public let completed: Int?
    public let total: Int?
    public let failed: Bool?
    public let linkingDone: Int?
    public let linkingTotal: Int?
    /// `settings` or `observed` (a job ran a stage the settings skip).
    public let optionalSource: String?

    public var isPhaseMode: Bool { mode == "phase" }
    /// Ring value: completed / total stages that run, never `phase_percent`.
    public var ring: Double {
        guard let total, total > 0 else { return 0 }
        return Double(completed ?? 0) / Double(total)
    }
    public var linking: QueueRules.Linking? {
        guard let total = linkingTotal, total > 0 else { return nil }
        return QueueRules.Linking(done: min(linkingDone ?? 0, total), total: total)
    }
}

/// One range group of a pack (`S03E01`…`S03E04`, or absolute `001`…`012`).
public struct QueuePackRange: Decodable, Sendable, Hashable {
    public let startLabel: String
    public let endLabel: String
    public let count: Int

    /// `S03E01–E04`, `001–012`, or one label when the range is a single episode.
    public var label: String {
        guard startLabel != endLabel else { return startLabel }
        if let s = startLabel.range(of: "E"), let e = endLabel.range(of: "E"),
           startLabel[..<s.lowerBound] == endLabel[..<e.lowerBound] {
            return startLabel + "–" + endLabel[e.lowerBound...]
        }
        return startLabel + "–" + endLabel
    }
}

/// A season pack's or anime batch's compact summary; each group nil when empty.
public struct QueuePackRanges: Decodable, Sendable, Hashable {
    public let done: QueuePackRange?
    public let current: QueuePackRange?
    public let waiting: QueuePackRange?
}

/// One episode a pack covers (`GET /queue/{id}/pack-episodes`).
public struct QueuePackEpisode: Decodable, Sendable, Hashable, Identifiable {
    public let episodeId: Int
    public let season: Int
    public let episode: Int
    public let absolute: Int?
    public let title: String?
    /// A held pack's decision for this episode's file (0.4.196).
    public let outcome: QueuePackOutcome?
    public var id: Int { episodeId }
}

public struct QueuePackEpisodesPage: Decodable, Sendable {
    public let items: [QueuePackEpisode]
    public let total: Int
    public let offset: Int
    public let limit: Int
}

/// The collapsed "Pipeline idle · Last import …" line (page 1 only).
public struct QueuePipeline: Decodable, Sendable, Hashable {
    public struct LastImport: Decodable, Sendable, Hashable {
        /// Naive UTC; parse with `ServerTime`.
        public let at: String
        public let title: String
        public let episodeLabel: String?
        public let mediaItemId: Int?
    }
    public let lastImport: LastImport?
}

/// Release facts parsed from the release name (the queue card's chips), the
/// same builder as Manual Import's `parsed` block. Only what the card shows.
public struct ReleaseFacts: Decodable, Sendable, Hashable {
    public let quality: String?
    public let edition: String?
    public let releaseGroup: String?
    public let languages: [String]?
    public let resolution: Int?
    public let source: String?
    public let isRemux: Bool?
    public let streamingService: String?
    public let videoCodec: String?
    public let dynamicRange: [String]?
    public let audioLabel: String?
    public let isRepack: Bool?
    public let isProper: Bool?
    /// The parsed season (packs) and year (movies).
    public let season: Int?
    public let year: Int?

    /// The chips in the web card's order: source/service, codec, HDR/DV,
    /// audio, edition, REPACK/PROPER, group. Languages are separate.
    public var chips: [String] {
        var out: [String] = []
        if isRemux == true { out.append("Remux") } else if let s = streamingService ?? source { out.append(s) }
        if let c = videoCodec { out.append(c) }
        out.append(contentsOf: dynamicRange ?? [])
        if let a = audioLabel { out.append(a) }
        if let e = edition, !e.isEmpty { out.append(e) }
        if isRepack == true { out.append("REPACK") }
        if isProper == true { out.append("PROPER") }
        if let g = releaseGroup, !g.isEmpty { out.append(g) }
        return out
    }
}

extension APIClient {
    /// A pack's episodes, paged (`GET /api/v1/queue/{id}/pack-episodes`).
    public func queuePackEpisodes(downloadId: Int, offset: Int = 0, limit: Int = 100) async throws -> QueuePackEpisodesPage {
        try await get("/api/v1/queue/\(downloadId)/pack-episodes",
                      query: [URLQueryItem(name: "offset", value: String(offset)),
                              URLQueryItem(name: "limit", value: String(limit))])
    }
}
