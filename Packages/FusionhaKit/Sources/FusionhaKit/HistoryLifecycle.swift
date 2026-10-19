import Foundation

/// A HELD history event's `data` (web `lib/held-event.ts`, backend `HeldEventData`).
public struct HeldEventData: Equatable, Sendable {
    public let reasonCode: String
    public let reason: String
    public let claimedQuality: String?
    public let probedQuality: String?
    public let probedResolution: HeldResolution?
    public let releaseGroup: String?
    public let downloadSize: Double?
    public let releaseBlocklisted: Bool

    /// nil unless `reason_code` is present (malformed data keeps the plain "Held").
    public static func parse(_ data: [String: LooseValue]?) -> HeldEventData? {
        guard let data, let code = data.value("reason_code"), case .string(let reasonCode) = code else { return nil }
        var resolution: HeldResolution?
        if case .object(let r)? = data.value("probed_resolution"), let w = r.number("w"), let h = r.number("h") {
            resolution = HeldResolution(w: Int(w), h: Int(h))
        }
        let blocklisted = data.value("release_blocklisted") == .bool(true)
        return HeldEventData(reasonCode: reasonCode, reason: data.text("reason") ?? "",
                             claimedQuality: string(data, "claimed_quality"), probedQuality: string(data, "probed_quality"),
                             probedResolution: resolution, releaseGroup: string(data, "release_group"),
                             downloadSize: data.number("download_size"), releaseBlocklisted: blocklisted)
    }

    private static func string(_ data: [String: LooseValue], _ key: String) -> String? {
        if case .string(let s)? = data.value(key) { return s }
        return nil
    }

    /// "1080p" -> 1080 (web `claimedFromQuality`).
    public static func resolution(in quality: String?) -> Int? {
        guard let quality, let r = quality.range(of: #"(\d{3,4})p"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return Int(quality[r].dropLast())
    }

    /// Backend `parser.bucket_resolution`.
    public static func bucket(w: Int, h: Int) -> Int {
        if w >= 3200 || h >= 1700 { return 2160 }
        if w >= 1800 || h >= 900 { return 1080 }
        if w >= 1200 || h >= 620 { return 720 }
        if w >= 1000 || h >= 560 { return 576 }
        return 480
    }

    public var claimedResolution: Int? { Self.resolution(in: claimedQuality) }
    public var fileResolution: Int? { Self.resolution(in: probedQuality) }

    /// `isProvenHeldMislabel`: claimed beats the probed bucket, both dimensions known.
    public var isProvenMislabel: Bool {
        guard reasonCode == "mislabeled_resolution", let claimed = claimedResolution, claimed > 0,
              let res = probedResolution, res.w > 0, res.h > 0 else { return false }
        return claimed > Self.bucket(w: res.w, h: res.h)
    }

    /// `heldStepTitle`: local titles for mislabel / kept-current, else the server's copy.
    public func stepTitle(held: HeldDisplay?) -> String {
        let local = reasonCode == "mislabeled_resolution" || reasonCode == "kept_current"
        if let held, !local { return held.stepTitle }
        switch reasonCode {
        case "mislabeled_resolution":
            let claimed = claimedResolution.map(String.init) ?? "?"
            if isProvenMislabel { return "Held: not really \(claimed)p" }
            if let c = claimedResolution, let f = fileResolution, probedResolution != nil {
                return "Held: release says \(c)p, file is \(f)p"
            }
            return "Held: resolution does not match the release name"
        case "not_an_upgrade": return "Held: not an upgrade"
        case "mislabeled_hdr": return "Held: HDR claim not in the file"
        case "kept_current": return "Kept the current file"
        case "corrupt": return "Held: corrupt or incomplete file"
        default: return reason.isEmpty ? "Held" : "Held: \(reason)"
        }
    }

    /// "Probed: 640×480 · Release says 1080p · file is 480p".
    public var probedLine: String? {
        guard let res = probedResolution else { return nil }
        return (["Probed: \(res.w)×\(res.h)"] + [claimedResolution.map { "Release says \($0)p" },
                                                fileResolution.map { "file is \($0)p" }].compactMap { $0 })
            .joined(separator: " · ")
    }
}

/// The History lifecycle sheet's pure parts (web `routes/activity/lifecycle/*`).
public enum HistoryLifecycleModel {
    public struct Version: Equatable, Sendable {
        public let id: Int
        public let tier: QualityTier
    }

    /// `S02E03 · Name` -> `S02·E03`; nil for a movie or an unparsed label.
    public static func episodeCode(_ label: String?) -> String? {
        guard let label, let r = label.range(of: #"S(\d+)\s*E(\d+)"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let digits = label[r].split(whereSeparator: { !$0.isNumber }).map(String.init)
        guard digits.count == 2 else { return nil }
        func pad(_ s: String) -> String { s.count < 2 ? "0" + s : s }
        return "S\(pad(digits[0]))·E\(pad(digits[1]))"
    }

    /// The active version's events; a pack-level HELD never reads as a hold on every episode.
    public static func events(_ items: [HistoryEntry], versionId: Int?, episodeId: Int?) -> [HistoryEntry] {
        items.filter { e in
            (versionId == nil || e.editionId == versionId)
                && !(e.eventType == "HELD" && episodeId != nil && e.episodeId == nil)
        }
    }

    /// The HD/4K switch: the active version first, then one version per other tier.
    public static func switchVersions(_ entries: [HistoryEntry], activeId: Int?, fallbackTier: QualityTier?) -> [Version] {
        var byId: [Int: Version] = [:]
        var order: [Int] = []
        for e in entries {
            guard let id = e.editionId, let tier = e.tier, byId[id] == nil else { continue }
            byId[id] = Version(id: id, tier: tier)
            order.append(id)
        }
        if let activeId, byId[activeId] == nil, let fallbackTier {
            byId[activeId] = Version(id: activeId, tier: fallbackTier)
            order.append(activeId)
        }
        guard let activeId, let active = byId[activeId] else { return [] }
        var seen: Set<QualityTier> = [active.tier]
        var out = [active]
        for id in order { if let v = byId[id], seen.insert(v.tier).inserted { out.append(v) } }
        return out
    }

    /// A failed step's humanized reason (never the raw string); nil for other steps.
    public static func failureLine(_ e: HistoryEntry) -> String? {
        guard ["GRAB_FAILED", "DOWNLOAD_FAILED", "FILE_MOVE_FAILED"].contains(e.eventType) else { return nil }
        // `historyFailureReason`: only grab/download failures carry `data.error`.
        let raw = e.eventType == "FILE_MOVE_FAILED" ? nil : e.data?.text("error")
        let f = FailureCopy.format(raw,
                                   context: e.eventType == "FILE_MOVE_FAILED" ? .import : .download)
        // The step already says "Download failed"; keep only a distinguishing title.
        return f.title.lowercased().hasSuffix("failed") ? f.detail : "\(f.title) — \(f.detail)"
    }
}
