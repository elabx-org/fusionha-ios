import Foundation

/// Plain-language copy for held downloads and the mislabel guard: the same
/// sentences as the web (`frontend/src/lib/mislabel-copy.ts`). No raw backend
/// text reaches the screen; codes and fields map to sentences here.
public enum HeldCopy {

    /// A proven fake: the detail says mislabeled, both probed dimensions are
    /// known, and the claimed resolution beats the measured bucket. The legacy
    /// tier-mismatch hold (no claim, no probe) never counts.
    public static func isProvenMislabel(_ detail: HeldDetail?) -> Bool {
        guard let detail, detail.mislabeled == true,
              let res = detail.probedResolution, res.w > 0, res.h > 0,
              let claimed = detail.claimedResolution, let bucket = detail.probedResolutionBucket else { return false }
        return claimed > bucket
    }

    /// "Not really 1080p: the file is 640×480. Release says 1080p."
    public static func mislabelLine(_ detail: HeldDetail) -> String {
        let claimed = detail.claimedResolution.map(String.init) ?? "?"
        let res = detail.probedResolution.map { "\($0.w)×\($0.h)" } ?? "?"
        return "Not really \(claimed)p: the file is \(res). Release says \(claimed)p."
    }

    /// `kind: "mislabeled_hdr"`: only a disproved HDR claim's custom-format
    /// points made the release look like an upgrade. Neutral when a side is missing.
    public static func hdrLine(_ detail: HeldDetail) -> String {
        guard let claim = detail.claimedHdr?.first, let file = detail.probedHdr else {
            return "Not an upgrade: the HDR claim isn't in the file."
        }
        return "Not an upgrade: name claimed \(claim), file is \(file)."
    }

    /// The headline for a held row: why it is held, in one sentence.
    public static func headline(_ detail: HeldDetail?, reason: String?) -> String? {
        if let detail {
            if isProvenMislabel(detail) { return mislabelLine(detail) }
            if detail.kind == "mislabeled_hdr" { return hdrLine(detail) }
            if detail.kind == "not_an_upgrade" { return "Not an upgrade over the copy you have." }
            if detail.kind == "kept_staging" { return "Kept in staging: the import didn't finish." }
        }
        return reason
    }

    /// A not-an-upgrade verdict in words (`HELD_VERDICT_LABEL`).
    public static func verdictLabel(_ code: String) -> String {
        switch code {
        case "quality_downgrade", "downgrade": return "quality downgrade"
        case "equal_quality_no_cf_gain", "same_quality", "no_score_gain": return "same quality, no score gain"
        case "quality_upgrade_below_cutoff", "meets_cutoff", "cutoff_met": return "already meets cutoff"
        case "not_allowed": return "not allowed by the profile"
        case "upgrades_disabled": return "upgrades are turned off"
        case "hdr_claim_not_upgrade": return "only a disproved HDR claim scored higher"
        default: return code.replacingOccurrences(of: "_", with: " ")
        }
    }

    /// Mirrors the backend's `bucket_resolution`: geometry to 2160/1080/720/576/480.
    public static func bucket(w: Int, h: Int) -> Int {
        if w >= 3200 || h >= 1700 { return 2160 }
        if w >= 1800 || h >= 900 { return 1080 }
        if w >= 1200 || h >= 620 { return 720 }
        if w >= 1000 || h >= 560 { return 576 }
        return 480
    }

    // MARK: Block release group?

    public enum BlockScope: String, CaseIterable, Sendable { case item, global, release }

    public static func scopeLabel(_ scope: BlockScope, group: String, title: String) -> String {
        switch scope {
        case .item: return "Skip \(group) for \(title)"
        case .global: return "Skip \(group) everywhere"
        case .release: return "Only this release"
        }
    }

    public static func customFormatName(group: String, claimedResolution: Int) -> String {
        "Fake \(claimedResolution)p: \(group)"
    }

    /// The "What this will do" lines for a scope.
    public static func consequences(_ scope: BlockScope, group: String, title: String,
                                    otherTitles: [String] = [], withCustomFormat: Bool = false) -> [String] {
        var lines: [String] = []
        switch scope {
        case .item:
            lines.append("\(group) releases are no longer grabbed for \(title).")
            lines.append("\(group) stays allowed for every other title.")
        case .global:
            lines.append("\(group) releases are no longer grabbed for any movie, series or anime.")
            if !otherTitles.isEmpty { lines.append("Also stops \(group)'s \(otherTitles.joined(separator: ", ")) release.") }
        case .release:
            return ["Leave the group alone. Its next release will download and be probed again."]
        }
        if withCustomFormat {
            lines.append("The custom format scores per quality profile, so it affects every title that uses those profiles.")
        }
        lines.append("The release you are looking at stays blocklisted. Your existing file is untouched.")
        return lines
    }

    public static let notNowNote = "Not now is not free. Until the group is blocked, its next release for any other title, "
        + "or for a missing episode of this one, is grabbed, downloaded and probed before it is held."

    public static let deleteBlockNote = "Unblocking does not delete the custom format it created. "
        + "Remove it in Settings › Custom formats if you no longer want it."

    /// Release-group endpoint codes (the web's `releaseGroupErrorMessage`).
    public static let errorCopy: [String: String] = [
        "invalid_group": "That is not a valid release group name.",
        "item_required": "Choose which title this block applies to.",
        "item_not_allowed": "An everywhere block cannot be tied to one title.",
        "item_not_found": "That title is no longer in your library.",
        "not_found": "That block no longer exists.",
        "not_allowed": "You need permission to manage quality settings to add a custom format.",
    ]

    public static func errorMessage(_ error: Error) -> String {
        if let code = (error as? APIError)?.code, let text = errorCopy[code] { return text }
        return ErrorCopy.generic
    }
}
