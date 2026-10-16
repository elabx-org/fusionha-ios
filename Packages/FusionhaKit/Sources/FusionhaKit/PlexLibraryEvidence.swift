import Foundation

// Pure copy + state helpers for the "4K Plex libraries" card (web
// `plex-server/plex-evidence.ts`).

public enum PlexLibraryState: String, Sendable, Hashable, CaseIterable {
    case uhd, suggested, notuhd, gone

    public var word: String {
        switch self {
        case .uhd: return "UHD·4K"
        case .suggested: return "Suggested"
        case .notuhd: return "Not 4K"
        case .gone: return "Gone from Plex"
        }
    }

    var summaryWord: String {
        switch self {
        case .uhd: return "count as 4K"
        case .suggested: return "need a decision"
        case .notuhd: return "not 4K"
        case .gone: return "gone"
        }
    }
}

public enum PlexLibraryEvidence {
    /// Mirrors the backend's MIN_SAMPLE (services/plex_path_match.py).
    static let minSample = 5

    public static func state(_ lib: PlexLibrary) -> PlexLibraryState {
        if lib.gone { return .gone }
        if lib.effectiveUhd { return .uhd }
        if lib.uhdDetected == "SUGGESTED" && lib.uhdOverride == nil { return .suggested }
        return .notuhd
    }

    public static func evidenceText(_ lib: PlexLibrary) -> String {
        let d = lib.detection
        if d?.method == "path" {
            let tick = d?.unique == true ? "✓" : "(ambiguous)"
            return "\(lib.title) ↔ /\(d?.matchedSuffix ?? "") \(tick) · matched \(d?.matched ?? 0) of \(d?.sampled ?? 0) sampled titles"
        }
        if d?.method == "name" {
            return "Name looks like 4K (“\(d?.matchedTitle ?? "")”) · confirm to use it"
        }
        return "No 4K root folder matches this library"
    }

    /// The Plex section path ↔ the fusionha root folder it matched.
    public static func pathPair(_ lib: PlexLibrary) -> (plex: String, root: String)? {
        guard let d = lib.detection, d.method == "path",
              let plex = d.plexPath, !plex.isEmpty, let root = d.rootPath, !root.isEmpty else { return nil }
        return (plex, root)
    }

    /// Why a row needs the admin (a suggestion), or why it no longer counts (gone).
    public static func decisionText(_ lib: PlexLibrary) -> String? {
        let st = state(lib)
        if st == .gone {
            return "No longer on your Plex server. Your \"4K\" setting is kept in case it comes back; it doesn't count meanwhile."
        }
        guard st == .suggested else { return nil }
        let d = lib.detection
        if d?.method == "path" && d?.unique != true {
            return "Needs your decision: this path matches more than one 4K root folder."
        }
        if d?.method == "path" && (d?.sampled ?? 0) < minSample {
            return "Needs your decision: only \(d?.sampled ?? 0) titles to sample, too few to be sure."
        }
        if d?.method == "name" { return "Needs your decision: only the name was checked (no server URL)." }
        return "A suggestion never applies on its own. Confirm it or set it by hand."
    }

    public struct SummaryChip: Sendable, Hashable, Identifiable {
        public let state: PlexLibraryState
        public let label: String
        public var id: PlexLibraryState { state }
    }

    /// The chip row above the list: one chip per non-empty state, in state order.
    public static func summary(_ libs: [PlexLibrary]) -> [SummaryChip] {
        var counts: [PlexLibraryState: Int] = [:]
        for l in libs { counts[state(l), default: 0] += 1 }
        return PlexLibraryState.allCases.compactMap { st in
            guard let n = counts[st], n > 0 else { return nil }
            return SummaryChip(state: st, label: "\(n) \(st.summaryWord)")
        }
    }

    public static func typeLabel(_ type: String) -> String {
        switch type {
        case "movie": return "Movies"
        case "show": return "TV"
        default: return type
        }
    }

    /// The toast after an override: "Films counts as 4K" …
    public static func overrideToast(_ title: String, _ value: String?) -> String {
        switch value ?? "" {
        case "ON": return "\(title) counts as 4K"
        case "OFF": return "\(title) set to Not 4K"
        default: return "\(title) back to detection"
        }
    }

    /// `3f9c2a1e…b7d4`: enough to tell two servers apart.
    public static func shortMachineId(_ id: String) -> String {
        id.count > 14 ? "\(id.prefix(8))…\(id.suffix(4))" : id
    }

    /// The ack stamp (naive UTC) as a local date, e.g. "6 Oct 2026".
    public static func formatAckDate(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "" }
        guard let date = ServerTime.parse(iso) else { return iso }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
