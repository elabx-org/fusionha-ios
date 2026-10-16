import Foundation

// The pure rules behind Import Library (web `import-review-filter.ts`,
// `import-triage.ts`, `import-root-config.ts`, `profile-kind.ts` and the
// formatters in `lib/api/import.ts`), kept out of the views so they're tested.

/// The confidence pill's tone: matched-high, matched-low, or no match.
public enum LibraryImportTone: String, Sendable {
    case hi, lo, no
}

/// The two triage groups: rows pinned to "Needs you" and settled "Ready" rows.
public struct LibraryImportTriage: Sendable, Hashable {
    public var needsYou: [LibraryImportItem] = []
    public var ready: [LibraryImportItem] = []
}

/// One tier's file count in the commit preview.
public struct LibraryImportTierCount: Sendable, Hashable {
    public let tier: QualityTier
    public let files: Int
}

public enum LibraryImportRules {
    // MARK: Roots

    /// A `*-4k` / 2160 / uhd root holds 4K versions.
    public static func inferTier(_ path: String) -> QualityTier {
        path.range(of: "4k|2160|uhd", options: [.regularExpression, .caseInsensitive]) != nil ? .uhd : .hd
    }

    /// tv / series / anime / show roots hold series, anything else movies.
    public static func inferKind(_ path: String) -> MediaKind {
        path.range(of: "tv|series|anime|show", options: [.regularExpression, .caseInsensitive]) != nil ? .series : .movie
    }

    public static func kindLabel(_ kind: MediaKind) -> String { kind == .series ? "Series" : "Movies" }

    /// Splits a path into its parent (which may truncate) and its leaf (always shown).
    public static func splitPath(_ path: String) -> (head: String, leaf: String) {
        guard let cut = path.lastIndex(of: "/") else { return ("", path) }
        let leaf = String(path[path.index(after: cut)...])
        let head = cut == path.startIndex ? "" : String(path[...cut])
        return (head, leaf.isEmpty ? path : leaf)
    }

    /// The resume card's root line: up to three paths, then "+N more".
    public static func rootLabel(_ draft: LibraryImportSummary) -> String {
        let roots = draft.roots ?? []
        if roots.isEmpty { return "\(plural(draft.sources ?? 0, "source")) scanned" }
        if roots.count <= 3 { return roots.joined(separator: " · ") }
        return roots.prefix(3).joined(separator: " · ") + " · +\(roots.count - 3) more"
    }

    // MARK: Triage

    /// high / exact / manual (or a number ≥ 90) is `hi`; any other match is `lo`.
    public static func tone(_ item: LibraryImportItem) -> LibraryImportTone {
        guard item.tmdbId != nil else { return .no }
        let c = item.confidence.lowercased()
        if c == "high" || c == "exact" || c == "manual" { return .hi }
        if let n = leadingNumber(c) { return n >= 90 ? .hi : .lo }
        return .lo
    }

    /// `parseFloat`: the number at the start of the text, if any.
    static func leadingNumber(_ text: String) -> Double? {
        var digits = ""
        for ch in text.trimmingCharacters(in: .whitespaces) {
            if ch.isNumber || (ch == "." && !digits.contains(".")) || (ch == "-" && digits.isEmpty) {
                digits.append(ch)
            } else {
                break
            }
        }
        return Double(digits)
    }

    /// Pinned to "Needs you": not confidently matched, or flagged by a rescan.
    /// A row whose every version is already owned is settled regardless.
    public static func needsAttention(_ item: LibraryImportItem) -> Bool {
        if item.alreadyImported == true { return false }
        return tone(item) != .hi || item.isNew == true || item.changedSinceReviewed == true
    }

    public static func partition(_ items: [LibraryImportItem]) -> LibraryImportTriage {
        var out = LibraryImportTriage()
        for item in items {
            if needsAttention(item) { out.needsYou.append(item) } else { out.ready.append(item) }
        }
        return out
    }

    // MARK: Quality profiles

    /// The item's kind (plus `anime` for an anime title) and legacy any-kind
    /// profiles; `keep` (the assigned one) always stays so it still renders.
    public static func profiles(_ all: [QualityProfile], kind: MediaKind, isAnime: Bool,
                                keep: Int? = nil) -> [QualityProfile] {
        var kinds: Set<String> = [kind.rawValue]
        if isAnime { kinds.insert("anime") }
        return all.filter { p in
            guard let k = p.mediaKind else { return true }
            return kinds.contains(k) || p.id == keep
        }
    }

    public static func profiles(_ all: [QualityProfile], for item: LibraryImportItem, keep: Int? = nil) -> [QualityProfile] {
        profiles(all, kind: item.kind, isAnime: item.isAnime == true, keep: keep)
    }

    /// The profile a row commits with: its own, else the first of its kind.
    public static func resolvedProfile(_ item: LibraryImportItem, in all: [QualityProfile]) -> Int? {
        item.qualityProfileId ?? profiles(all, for: item).first?.id
    }

    /// Accepting a row stamps a profile when it has none, so the commit never lacks one.
    public static func acceptPatch(_ item: LibraryImportItem, accepted: Bool, profiles all: [QualityProfile]) -> LibraryImportPatch {
        var patch = LibraryImportPatch(scanId: item.scanId, folderKey: item.folderKey, accepted: accepted)
        if accepted, item.qualityProfileId == nil { patch.qualityProfileId = resolvedProfile(item, in: all) }
        return patch
    }

    /// Accept all N: every matched, not-yet-accepted Ready row, skipping titles already owned.
    public static func acceptAllPatches(_ ready: [LibraryImportItem], profiles all: [QualityProfile]) -> [LibraryImportPatch] {
        ready.filter { $0.matched && !$0.accepted && $0.alreadyImported != true }
            .map { acceptPatch($0, accepted: true, profiles: all) }
    }

    /// The bulk picker's options for a kind: the union of each matched row's own picks.
    public static func bulkOptions(_ matched: [LibraryImportItem], kind: MediaKind,
                                   profiles all: [QualityProfile]) -> [QualityProfile] {
        var seen = Set<Int>()
        var out: [QualityProfile] = []
        for row in matched where row.kind == kind {
            for p in profiles(all, for: row) where !seen.contains(p.id) {
                seen.insert(p.id)
                out.append(p)
            }
        }
        return out
    }

    /// The rows a bulk apply touches: that kind, and only where the profile fits the row.
    /// Before a profile is chosen it counts every row of the kind.
    public static func bulkTargets(_ matched: [LibraryImportItem], kind: MediaKind, profileId: Int?,
                                   profiles all: [QualityProfile]) -> [LibraryImportItem] {
        matched.filter { row in
            guard row.kind == kind else { return false }
            guard let profileId else { return true }
            return profiles(all, for: row).contains { $0.id == profileId }
        }
    }

    // MARK: Copy

    public static func plural(_ n: Int, _ word: String) -> String {
        "\(grouped(n)) \(word)\(n == 1 ? "" : "s")"
    }

    /// `toLocaleString()` for en: 1240 → "1,240".
    public static func grouped(_ n: Int) -> String {
        let digits = String(abs(n))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0, (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return n < 0 ? "-" + out : out
    }

    /// The commit bar: "12 titles · 20 files — adopt in place".
    public static func previewLine(_ preview: LibraryImportPreview?) -> String {
        "\(plural(preview?.titles ?? 0, "title")) · \(plural(preview?.files ?? 0, "file")) — adopt in place"
    }

    /// The per-tier breakdown, HD first, empty tiers left out.
    public static func previewTiers(_ preview: LibraryImportPreview?) -> [LibraryImportTierCount] {
        let perTier = preview?.perTier ?? [:]
        var out: [LibraryImportTierCount] = []
        for tier in [QualityTier.hd, QualityTier.uhd] {
            if let n = perTier[tier.rawValue], n > 0 { out.append(LibraryImportTierCount(tier: tier, files: n)) }
        }
        return out
    }

    /// A Sources card's status line.
    public static func sourceLine(_ source: LibraryImportSource) -> String {
        let scanning = source.status == "scanning"
        let stalled = scanning && source.stalled == true
        if stalled { return "Stalled — mount may be unresponsive" }
        if source.status == "interrupted" { return "Interrupted — Rescan" }
        if scanning {
            let total = source.scanTotal ?? 0
            guard total > 0 else { return "Scanning…" }
            let phase = source.scanPhase == "filescan" ? "scanning files" : (source.scanPhase == "done" ? "finishing" : "matching")
            return "\(source.scanDone ?? 0) of \(total) · \(phase)"
        }
        if source.status == "failed" {
            return "Scan failed" + (source.error.map { " — \($0)" } ?? "")
        }
        return "\(plural(source.items ?? 0, "title")) · \(plural(source.files ?? 0, "file"))"
    }

    /// 0…1 when the scan has published a total, else nil (indeterminate).
    public static func sourceProgress(_ source: LibraryImportSource) -> Double? {
        guard source.status == "scanning", let total = source.scanTotal, total > 0 else { return nil }
        return min(1, Double(source.scanDone ?? 0) / Double(total))
    }

    /// Rescan is offered unless the scan is actively (not stalled) running.
    public static func canRescan(_ source: LibraryImportSource) -> Bool {
        source.status != "scanning" || source.stalled == true
    }

    // MARK: Polling

    /// Poll while a source is genuinely scanning, while the commit runs (unless
    /// stalled), or while a committed import is still analysing its files.
    public static func needsPolling(_ session: LibraryImportSession) -> Bool {
        if session.isCommitting { return session.commitStalled != true }
        if session.isCommitted { return session.enrichment?.state == "analyzing" }
        return (session.sources ?? []).contains { $0.status == "scanning" && $0.stalled != true }
    }

    /// The optimistic edit: patches applied by key, attention flags cleared (a PATCH is a review).
    public static func applying(_ patches: [LibraryImportPatch], to session: LibraryImportSession) -> LibraryImportSession {
        guard !patches.isEmpty, let items = session.items else { return session }
        var byKey: [String: LibraryImportPatch] = [:]
        for p in patches { byKey[p.key] = byKey[p.key].map { $0.merged(with: p) } ?? p }
        var next = session
        next.items = items.map { item in
            guard let p = byKey[item.id] else { return item }
            var row = item
            if let v = p.accepted { row.accepted = v }
            if let v = p.monitored { row.monitored = v }
            if let v = p.qualityProfileId { row.qualityProfileId = v }
            if let v = p.variant { row.variant = v }
            row.isNew = false
            row.changedSinceReviewed = false
            return row
        }
        return next
    }
}
