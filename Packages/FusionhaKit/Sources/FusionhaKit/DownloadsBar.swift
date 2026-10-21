import Foundation

/// The downloads bar (iOS's tab-bar bottom accessory): which download leads
/// it, and its words, from the queue the app already polls. iOS-only: the web
/// has no equivalent.
public enum DownloadsBar {
    /// Why a download needs the person, in the order the bar ranks them.
    public enum Need: Equatable, Sendable {
        /// Held for a manual import.
        case held
        /// The download or its import failed.
        case failed
        /// fusionha flagged it (no release left to try).
        case stuck
    }

    public struct Summary: Equatable, Sendable {
        public let leadId: Int
        public let mediaItemId: Int
        public let title: String
        /// `S02E07`, from the episode label.
        public let episodeCode: String?
        public let posterUrl: String?
        public let leadTier: QualityTier
        /// Every tier on the queue, the lead's first (the inline line's chips).
        public let tiers: [QualityTier]
        public let need: Need?
        /// The need in words: "Import waiting".
        public let reason: String?
        /// Items still moving (everything that doesn't need the person).
        public let downloading: Int
        /// Overall progress of the moving items, 0–100.
        public let percent: Int
        /// The lead's own progress, 0–1 (the hairline).
        public let leadFraction: Double
        public let bytesDone: Double
        public let bytesTotal: Double
        /// The longest time left the download clients report.
        public let etaSeconds: Int?

        /// "Severance S02E07".
        public var heading: String { [title, episodeCode].compactMap { $0 }.joined(separator: " ") }
    }

    // MARK: Ranking

    public static func need(_ item: QueueItem) -> Need? {
        let status = item.status.lowercased()
        if status == "held" { return .held }
        if status == "failed" || item.outcome?.lowercased() == "failed" { return .failed }
        if item.needsAttention == true { return .stuck }
        return nil
    }

    /// Transferring bytes now (not waiting, importing or held).
    static func isActive(_ item: QueueItem) -> Bool {
        guard need(item) == nil, !item.stalled else { return false }
        let status = item.status.lowercased()
        return !["queued", "delay", "pending", "paused", "completed"].contains(status) && item.progress < 100
    }

    /// Needs you (held › failed › stuck) › the largest active download › the most recent.
    public static func lead(_ items: [QueueItem]) -> QueueItem? {
        for kind in [Need.held, .failed, .stuck] {
            if let item = items.first(where: { need($0) == kind }) { return item }
        }
        if let largest = items.filter(isActive).max(by: { $0.size < $1.size }) { return largest }
        return items.min { ($0.ageSeconds ?? .infinity) < ($1.ageSeconds ?? .infinity) }
    }

    public static func summary(_ items: [QueueItem]) -> Summary? {
        guard let lead = lead(items) else { return nil }
        let moving = items.filter { need($0) == nil }
        let sized = moving.filter { $0.size > 0 }
        let total = sized.reduce(0) { $0 + $1.size }
        let done = sized.reduce(0) { $0 + max(0, $1.size - $1.sizeleft) }
        let percent: Int
        if total > 0 {
            percent = clampPercent(done / total * 100)
        } else {
            let all = moving.isEmpty ? items : moving
            percent = clampPercent(all.reduce(0) { $0 + $1.progress } / Double(max(all.count, 1)))
        }
        var tiers = [lead.tier]
        for item in items where !tiers.contains(item.tier) { tiers.append(item.tier) }
        let leadNeed = need(lead)
        return Summary(leadId: lead.id, mediaItemId: lead.mediaItemId, title: lead.title,
                       episodeCode: episodeCode(lead.episodeLabel), posterUrl: lead.posterUrl,
                       leadTier: lead.tier, tiers: tiers, need: leadNeed, reason: leadNeed.map { reason($0, lead) },
                       downloading: moving.count, percent: percent, leadFraction: lead.fraction,
                       bytesDone: done, bytesTotal: total,
                       etaSeconds: moving.compactMap(\.etaSeconds).filter { $0 > 0 }.max())
    }

    /// The moment after the last download leaves: the lead the bar last showed,
    /// unless it was waiting on the person (then it was removed, not imported).
    public static func finished(previous: Summary?, nowEmpty: Bool) -> Summary? {
        guard nowEmpty, let previous, previous.need == nil else { return nil }
        return previous
    }

    // MARK: Words

    static func reason(_ need: Need, _ item: QueueItem) -> String {
        switch need {
        case .held: return item.held?.short ?? "Import waiting"
        case .failed: return "Download failed"
        case .stuck: return "No release left to try"
        }
    }

    /// Expanded second line: "3 downloading · 2.1 of 5.8 GB · 6 min", or for a
    /// need, "Import waiting · +2 downloading".
    public static func detailLine(_ s: Summary) -> String {
        if let reason = s.reason {
            return s.downloading > 0 ? "\(reason) · +\(s.downloading) downloading" : reason
        }
        var parts = ["\(s.downloading) downloading"]
        if s.bytesTotal > 0 { parts.append(sizes(done: s.bytesDone, total: s.bytesTotal)) }
        if let eta = s.etaSeconds { parts.append(duration(eta)) }
        return parts.joined(separator: " · ")
    }

    /// Inline (minimised) line: "3 downloading", or the need's words.
    public static func inlineLine(_ s: Summary) -> String {
        s.reason ?? "\(s.downloading) downloading"
    }

    public static let finishedLine = "Imported · ready in Plex"

    /// VoiceOver: "Downloads, 3 downloading, 42 percent. Severance season 2 episode 7, 4K."
    public static func spoken(_ s: Summary) -> String {
        var head = "Downloads"
        if let reason = s.reason { head += ", needs you: \(reason)" }
        head += ", \(s.downloading) downloading, \(s.percent) percent."
        return "\(head) \(spokenTitle(s))."
    }

    public static func spokenFinished(_ s: Summary) -> String {
        "Downloads, imported and ready in Plex. \(spokenTitle(s))."
    }

    static func spokenTitle(_ s: Summary) -> String {
        var title = s.title
        if let code = s.episodeCode, let match = code.wholeMatch(of: #/S(\d+)E(\d+)/#),
           let season = Int(match.1), let episode = Int(match.2) {
            title += " season \(season) episode \(episode)"
        }
        return "\(title), \(s.leadTier == .uhd ? "4K" : "HD")"
    }

    /// "2.1 of 5.8 GB" in one unit, else "640 MB of 1.4 GB".
    public static func sizes(done: Double, total: Double) -> String {
        let doneText = DetailText.bytes(max(done, 0)), totalText = DetailText.bytes(total)
        let doneParts = doneText.split(separator: " "), totalParts = totalText.split(separator: " ")
        if doneParts.count == 2, totalParts.count == 2, doneParts[1] == totalParts[1] {
            return "\(doneParts[0]) of \(totalText)"
        }
        return "\(doneText) of \(totalText)"
    }

    /// "6 min", "1 h 20 min", "<1 min".
    public static func duration(_ seconds: Int) -> String {
        let minutes = Int((Double(seconds) / 60).rounded())
        if minutes < 1 { return "<1 min" }
        if minutes < 60 { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
    }

    /// `S02E07 · Name` → `S02E07`.
    static func episodeCode(_ label: String?) -> String? {
        guard let label, let code = label.split(separator: "·").first?.trimmingCharacters(in: .whitespaces),
              !code.isEmpty else { return nil }
        return code
    }

    static func clampPercent(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(min(100, max(0, value.rounded())))
    }
}
