import Foundation

/// Turns a raw backend download/import failure reason into friendly copy: the
/// port of the web's `lib/failure-format.ts`. Known failures get a title and a
/// detail with the real numbers; unknown ones are stripped of wire noise,
/// de-duplicated and sentence-cased. `raw` is always kept for a Details disclosure.
public enum FailureCopy {

    public enum Kind: String, Sendable, Equatable {
        case deadPost = "dead_post", knownBad = "known_bad", linkExpired = "link_expired"
        case noSpace = "no_space", timeout, provider, unpack, `import`, download, unknown
    }

    /// Where the reason surfaced; tunes only the fallback title and kind.
    public enum Context: Sendable { case download, `import`, blocklist }

    public struct Formatted: Sendable, Equatable {
        public let title: String
        public let detail: String
        /// A muted trailing clause, or nil when the kind has none.
        public let sub: String?
        /// The exact original reason ("" when blank).
        public let raw: String
        public let kind: Kind
        /// Only a proven-bad content failure (dead post, known bad).
        public let isContentFailure: Bool

        /// The raw text differs from what the friendly lines already say.
        public var hasDetails: Bool { !raw.isEmpty && raw != detail }
    }

    public static func format(_ input: String?, context: Context = .download) -> Formatted {
        let raw = (input ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let isImport = context == .import
        guard !raw.isEmpty else {
            return Formatted(title: isImport ? "Import failed" : "Download failed",
                             detail: isImport ? "The import failed." : "The download failed.",
                             sub: nil, raw: "", kind: .unknown, isContentFailure: false)
        }
        if let kind = classify(raw), let text = knownText(kind, raw: raw) {
            return Formatted(title: text.title, detail: text.detail, sub: text.sub, raw: raw,
                             kind: kind, isContentFailure: kind == .deadPost || kind == .knownBad)
        }
        let fallback: Kind = switch context {
        case .import: .import
        case .download: .download
        case .blocklist: .unknown
        }
        return Formatted(title: isImport ? "Import failed" : "Download failed",
                         detail: cleanCore(raw), sub: nil, raw: raw, kind: fallback, isContentFailure: false)
    }

    // MARK: - Classification

    private static let markerKind: [String: Kind] = [
        "dead_articles": .deadPost, "decode_giveup": .provider, "provider_busy": .provider,
        "provider_auth": .provider, "provider_timeout": .provider, "provider_connection": .provider,
        "connection_cap": .provider, "structural": .unpack,
    ]

    private static let proseMatchers: [(Kind, [String])] = [
        (.knownBad, [#"known[- ]bad"#, #"rejected (?:release )?as known"#]),
        (.deadPost, [#"dead[_ ]articles?"#, "every provider denied", "no valid files", "no articles",
                     "no such article", "article not found", "article not available",
                     #"missing articles?"#, "articles are missing", #"\bretention\b"#]),
        (.noSpace, ["no space", "disk full", "out of space", "enospc"]),
        (.timeout, ["timed out", #"\btimeout\b"#]),
        (.linkExpired, ["link death", "link expired", #"\bdangling\b"#, #"\bmount\b"#,
                        #"\bvanished\b"#, "no longer in queue", "removed by download client"]),
        (.provider, [#"decode[_ ]giveup"#, #"provider[_ ](?:busy|auth|timeout|connection)"#,
                     "provider busy", #"connection[_ ]cap"#]),
        (.unpack, ["unpack", #"\bextract"#, "repair failed", "damaged and cannot be repaired",
                   "broken nzb", "invalid nzb", "failed to verify"]),
    ]

    static func classify(_ raw: String) -> Kind? {
        if let token = firstGroups(#"\[decypharr[- ]reason=([a-z_]+)\]"#, in: raw)?.first,
           let mapped = markerKind[token.lowercased()] {
            return mapped
        }
        for (kind, patterns) in proseMatchers where patterns.contains(where: { matches($0, raw) }) {
            return kind
        }
        return nil
    }

    private static func knownText(_ kind: Kind, raw: String) -> (title: String, detail: String, sub: String?)? {
        switch kind {
        case .deadPost:
            let groups = extractGroups(raw).map { "\($0.failed)/\($0.total) groups · " } ?? ""
            return ("Dead post", "Every provider denied the post (\(groups)dead articles).",
                    "Blocklisted this release · re-searching for another.")
        case .knownBad: return ("Known-bad release", "Previously found bad.", "Re-searching for another release.")
        case .linkExpired: return ("Link expired", "The download link expired.", "Retrying.")
        case .noSpace: return ("No disk space", "No space left on the root folder.", "Retrying.")
        case .timeout: return ("Timed out", "The request timed out.", "Retrying.")
        case .provider: return ("Provider error", "The usenet provider couldn't serve it.", "Retrying.")
        case .unpack: return ("Unpack failed", "The archive couldn't be unpacked.", "Re-searching for another release.")
        default: return nil
        }
    }

    static func extractGroups(_ raw: String) -> (failed: Int, total: Int)? {
        let found = firstGroups(#"(\d+)\s*/\s*(\d+)\s*groups?\s*failed"#, in: raw)
            ?? firstGroups(#"(\d+)\s*/\s*(\d+)\s*groups?"#, in: raw)
        guard let found, found.count == 2, let f = Int(found[0]), let t = Int(found[1]) else { return nil }
        return (f, t)
    }

    /// Strip the marker and nested noise prefixes, de-dupe ": " clauses, sentence-case.
    static func cleanCore(_ raw: String) -> String {
        var s = replace(#"\s*\[decypharr[- ]reason=[^\]]*\]\s*"#, in: raw, with: " ")
        let prefix = #"^\s*(?:failed to process nzb archives:|failed to process nzb:|import error:|error:)\s*"#
        var previous: String
        repeat {
            previous = s
            s = replace(prefix, in: s, with: "")
        } while s != previous
        var seen = Set<String>()
        let parts = replace(#":\s+"#, in: s, with: "\u{1F}").components(separatedBy: "\u{1F}")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        s = replace(#"\s+"#, in: parts.joined(separator: ": "), with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = s.first else { return raw.trimmingCharacters(in: .whitespacesAndNewlines) }
        return first.uppercased() + s.dropFirst()
    }

    // MARK: - Regex helpers

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func matches(_ pattern: String, _ s: String) -> Bool {
        regex(pattern)?.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    private static func firstGroups(_ pattern: String, in s: String) -> [String]? {
        guard let re = regex(pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (1..<m.numberOfRanges).compactMap { Range(m.range(at: $0), in: s).map { String(s[$0]) } }
    }

    private static func replace(_ pattern: String, in s: String, with template: String) -> String {
        guard let re = regex(pattern) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s),
                                           withTemplate: NSRegularExpression.escapedTemplate(for: template))
    }
}
