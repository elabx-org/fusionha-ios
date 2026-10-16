import Foundation

// The Manual Import row rules, ported from the web
// (`routes/manual-import/{row-labels,status-icon,status-long,selection}.ts`):
// one status per row, which rows a tick imports, and the words for each.

/// A row's one status (the web's `StatusIconKey`), in `statusShort`'s precedence.
public enum ManualImportStatus: String, CaseIterable, Sendable {
    case ready, upgrade, notUpgrade, downgrade, keep, lowConfidence, nameFile
    case titleEpisode, noEpisode, noMatch, held, imported

    /// The key's name for the status.
    public var name: String {
        switch self {
        case .ready: return "Ready"
        case .upgrade: return "Upgrade"
        case .notUpgrade: return "Not an upgrade"
        case .downgrade: return "Downgrade"
        case .keep: return "Keeping current"
        case .lowConfidence: return "Low confidence"
        case .nameFile: return "Name ≠ file"
        case .titleEpisode: return "Title ≠ episode"
        case .noEpisode: return "Episode not found"
        case .noMatch: return "No match"
        case .held: return "Held / needs a look"
        case .imported: return "Imported"
        }
    }
}

public enum ManualImportRules {

    // MARK: Status

    public static func verdict(_ row: ManualImportRow) -> ManualImportReplaceVerdict? { row.existingFile?.verdict }

    public static func status(_ row: ManualImportRow) -> ManualImportStatus {
        if row.committed { return .imported }
        if row.status == "no_match" { return .noMatch }
        if titleBlocked(row) { return .titleEpisode }
        if row.wouldOrphan != nil { return .held }
        if row.measured?.mislabeled == true, row.mismatchChoice == nil, row.held == nil { return .nameFile }
        if row.replaceChoice == "keep_current" { return .keep }
        let v = verdict(row)
        if let v, v.upgrade != true, row.replaceChoice == nil, row.held == nil { return .notUpgrade }
        if row.match.alternative?.reason == "episode_title", row.titleCheckDismissed != true { return .titleEpisode }
        // A hold is a guarded downgrade: only a verdict that says upgrade earns ↑.
        if row.existingFile != nil, row.held != nil {
            if v?.upgrade == true { return .upgrade }
            return row.replaceChoice == "import" ? .downgrade : .notUpgrade
        }
        if row.status == "needs_attention", ["medium", "low"].contains(row.match.confidence ?? "") { return .lowConfidence }
        if row.status == "ready" {
            guard row.existingFile != nil else { return .ready }
            return v != nil && v?.upgrade != true && row.replaceChoice == "import" ? .downgrade : .upgrade
        }
        if (row.statusReason ?? "").hasPrefix("Couldn't resolve") { return .noEpisode }
        return .held
    }

    /// The status in a few words (`statusShort`).
    public static func statusShort(_ row: ManualImportRow) -> String {
        if row.committed { return "Imported" }
        if row.status == "no_match" { return "No match" }
        if titleBlocked(row) { return "Title ≠ episode" }
        if row.wouldOrphan != nil { return "Shared file" }
        if row.measured?.mislabeled == true, row.mismatchChoice == nil, row.held == nil { return "Name ≠ file" }
        if row.replaceChoice == "keep_current" { return "Keeping the current file" }
        let v = verdict(row)
        if let v, v.upgrade != true, row.replaceChoice == nil, row.held == nil {
            return v.hdrOnly == true ? "Not an upgrade without \(claimLabel(v))" : "Not an upgrade"
        }
        if row.match.alternative?.reason == "episode_title", row.titleCheckDismissed != true { return "Title ≠ episode" }
        if row.held != nil, row.existingFile != nil, v?.upgrade != true, row.replaceChoice == nil { return "Not an upgrade" }
        let downgrade = v != nil && v?.upgrade != true && row.replaceChoice == "import" ? " · not an upgrade" : ""
        let replaces = row.existingFile.map { "Replaces \(DetailText.quality($0.quality))\(downgrade)" }
        if let replaces, row.held != nil { return replaces }
        if row.status == "needs_attention", ["medium", "low"].contains(row.match.confidence ?? "") { return "Low confidence" }
        if row.status == "ready" { return replaces ?? "Ready" }
        let reason = row.statusReason ?? "Needs attention"
        if reason.hasPrefix("Set quality") { return "Set quality" }
        if reason.hasPrefix("Couldn't resolve") { return "Couldn't resolve episode" }
        if reason.hasPrefix("New ") { return "Needs root & profile" }
        return reason.components(separatedBy: " — ").first ?? reason
    }

    /// The status in full (`statusLong`): "Held · not an upgrade · replaces your 4K FUZEER copy".
    public static func statusLong(_ row: ManualImportRow) -> String {
        let short = statusShort(row)
        if titleBlocked(row), let tc = row.titleCheck {
            return "Title ≠ episode · the file says '\(tc.says ?? "")', that is \(tc.matchesEpisode?.code ?? "another episode")"
        }
        if row.wouldOrphan != nil, !row.committed, let orphan = orphanText(row) { return "\(short) · \(orphan)" }
        let group = row.existingFile?.releaseGroup ?? copyName(row)
        switch status(row) {
        case .imported: return short
        case .ready: return row.existingFile != nil ? short : "Ready · new"
        case .upgrade:
            return row.held != nil && row.replaceChoice == nil
                ? "Upgrade · replaces \(group) · pick to import" : "Upgrade · replaces \(group)"
        case .downgrade: return "Downgrade · replaces your \(copyName(row)) copy"
        case .keep: return "Keeping current · your \(copyName(row)) copy stays"
        case .notUpgrade:
            return row.held != nil
                ? "Held · not an upgrade · replaces your \(copyName(row)) copy"
                : "\(short) · replaces your \(copyName(row)) copy"
        default: return withReason(short, row.statusReason)
        }
    }

    /// "4K FUZEER" / "FLUX": the copy on disk (its group, else its quality); only 4K is named.
    static func copyName(_ row: ManualImportRow) -> String {
        let cur = row.existingFile
        let group = cur?.releaseGroup ?? cur.map { DetailText.quality($0.quality) } ?? ""
        let named = row.target.tier == QualityTier.uhd.rawValue ? "4K \(group)" : group
        // A non-Standard cut leads, so Standard and Extended copies of one tier differ.
        return row.target.edition.map { "\($0) · \(named)" } ?? named
    }

    private static func withReason(_ short: String, _ reason: String?) -> String {
        guard let reason, reason != short else { return short }
        let tail = reason.range(of: " — ").map { String(reason[$0.upperBound...]) }
        if reason.hasPrefix(short) { return tail.map { "\(short) · \($0)" } ?? reason }
        return "\(short) · \(tail ?? reason)"
    }

    private static func claimLabel(_ v: ManualImportReplaceVerdict) -> String {
        let first = v.absent?.first ?? "HDR10"
        return first == "HDR10" ? "HDR" : first
    }

    /// The advisory the server attaches (corroboration, or the competing match).
    public static func advisory(_ row: ManualImportRow) -> String? {
        // The real cause first: a title that names another episode, then a two-parter.
        if titleBlocked(row), let tc = row.titleCheck {
            let there = episodeCode(row)
            return "File says '\(tc.says ?? "")' — that's \(tc.matchesEpisode?.code ?? "another episode") in your library\(there.map { ", not \($0)" } ?? "")"
        }
        if row.recommended == "assign_episodes", let rec = row.recommendedEpisodes, rec.count > 1, !row.committed {
            return "This file holds \(episodesLabel(rec)) — assign both to replace the two-parter"
        }
        if row.wouldOrphan != nil { return orphanText(row) }
        if let note = row.corroboration { return note }
        guard let alt = row.match.alternative,
              !(alt.reason == "episode_title" && row.titleCheckDismissed == true) else { return nil }
        let label = alt.title + (alt.year.map { " (\($0))" } ?? "")
        let kind = alt.kind == "movie" ? "Movie" : alt.kind == "series" ? "Series" : alt.kind.capitalized
        return alt.reason == "also_matches" ? "Also matches \(label) · \(kind)" : "Filename title matches \(label)"
    }

    // MARK: Selection (select is not import)

    /// A folder-scan row that would replace a better file and waits for its choice.
    public static func awaitsReplaceChoice(_ row: ManualImportRow) -> Bool {
        guard let v = verdict(row), v.upgrade != true, !row.committed, row.held == nil,
              row.replaceChoice == nil, row.status == "needs_attention" else { return false }
        let reason = row.statusReason ?? ""
        return reason.hasPrefix("Not an upgrade") || reason.hasPrefix("Only the claimed")
    }

    private static func heldWarning(_ row: ManualImportRow) -> Bool {
        row.held != nil && row.status == "needs_attention" && row.selected
    }

    /// A download held on probe proof over a file on disk: it arrives unticked.
    public static func provenMislabelHold(_ row: ManualImportRow) -> Bool {
        guard let held = row.held, row.existingFile != nil else { return false }
        return held.detail?.mislabeled == true || (held.detail?.kind ?? "").hasPrefix("mislabeled")
    }

    /// What the default selection and select-all pick.
    public static func isBulkSelectable(_ row: ManualImportRow) -> Bool {
        if row.committed || row.replaceChoice == "keep_current" || row.wouldOrphan != nil || titleBlocked(row) { return false }
        if provenMislabelHold(row), row.replaceChoice != "import" { return false }
        return row.status == "ready" || (heldWarning(row) && (row.statusReason ?? "").hasPrefix("Replaces"))
    }

    static func isSelectable(_ row: ManualImportRow) -> Bool {
        if row.committed || row.replaceChoice == "keep_current" || row.wouldOrphan != nil || titleBlocked(row) { return false }
        return isBulkSelectable(row) || heldWarning(row) || awaitsReplaceChoice(row)
    }

    /// Whether a ticked row imports (never one still awaiting a choice).
    public static func isImportable(_ row: ManualImportRow) -> Bool {
        isSelectable(row) && !awaitsReplaceChoice(row)
    }

    /// A medium match the user can confirm as is (web `confirmEligible`).
    public static func confirmEligible(_ row: ManualImportRow) -> Bool {
        !row.committed && row.status == "needs_attention" && row.match.itemId != nil
            && row.match.confidence != "high" && row.itemOverridden != true
    }

    /// The server's per-row default, filtered the way the web seeds its ticks.
    public static func initialSelection(_ scan: ManualImportScan) -> Set<Int> {
        Set(scan.rows.filter { $0.selected && isBulkSelectable($0) }.map(\.rowId))
    }

    // MARK: Row text

    /// `S04E02` / `S06E05–E06`; nil for a movie or an unresolved number.
    public static func episodeCode(_ row: ManualImportRow) -> String? {
        guard row.target.isSeries, let season = row.target.season ?? row.parsed.season else { return nil }
        let parsed = row.parsed.episodes ?? []
        let eps = parsed.isEmpty ? (row.target.episode.map { [$0] } ?? []) : parsed
        guard let first = eps.first, let last = eps.last else { return nil }
        return EpisodeCode.range(season: season, first: first, last: last, separator: "")
    }

    /// `HD·1080p` / `UHD·4K` for a tier string.
    public static func tierLabel(_ tier: String?) -> String {
        guard let tier, let t = QualityTier(rawValue: tier) else { return tier ?? "—" }
        return t.chipLabel
    }

    public static func probeErrorText(_ error: String?) -> String {
        switch error {
        case "timeout": return "The file didn't answer in time"
        case "ffprobe_missing": return "ffprobe isn't installed"
        default: return "ffprobe couldn't read the file"
        }
    }

    /// Every quality the override offers, best first (`QUALITY_ORDER`).
    public static let qualityOrder: [String] = [
        "REMUX_2160P", "BLURAY_2160P", "WEBDL_2160P", "WEBRIP_2160P", "HDTV_2160P", "REMUX_1080P",
        "BLURAY_1080P", "WEBDL_1080P", "WEBRIP_1080P", "RAWHD", "HDTV_1080P", "BLURAY_720P", "WEBDL_720P",
        "WEBRIP_720P", "HDTV_720P", "BLURAY_576P", "BLURAY_480P", "DVD", "DVDR", "WEBDL_480P", "WEBRIP_480P",
        "SDTV", "BRDISK", "DVDSCR", "REGIONAL", "TELECINE", "TELESYNC", "CAM", "WORKPRINT",
    ]

    /// The `Language` enum, offered as the per-row language override.
    public static let languages: [String] = [
        "Unknown", "English", "Japanese", "French", "Spanish", "German", "Italian", "Korean", "Chinese",
        "Portuguese", "Portuguese (Brazil)", "Spanish (Latino)", "Russian", "Dutch", "Danish", "Swedish",
        "Norwegian", "Finnish", "Polish", "Turkish", "Greek", "Hebrew", "Arabic", "Hindi", "Tamil", "Thai",
        "Vietnamese", "Indonesian", "Czech", "Hungarian", "Romanian", "Ukrainian", "Bulgarian", "Croatian",
        "Serbian", "Slovak", "Slovenian", "Catalan", "Persian",
    ]

    public struct ReleaseType: Hashable, Sendable {
        public let value: String
        public let label: String
    }

    /// The arr release types.
    public static let releaseTypes: [ReleaseType] = [
        .init(value: "unknown", label: "Unknown"), .init(value: "singleEpisode", label: "Single episode"),
        .init(value: "multiEpisode", label: "Multi episode"), .init(value: "seasonPack", label: "Season pack"),
    ]
}
