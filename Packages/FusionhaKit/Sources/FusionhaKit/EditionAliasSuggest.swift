import Foundation

/// "Always treat this as <edition> for this title" on a rejected release
/// (edition-alias-suggest.ts): reads the edition-mismatch reason and guesses
/// the release's edition term.
public enum EditionAliasSuggest {
    public struct Mismatch: Equatable, Sendable {
        public let releaseEdition: String
        public let tracked: String
    }

    /// `decision/reasons.py::edition_mismatch`; the tracked value may itself
    /// hold an apostrophe ("Director's Cut"), so it runs to the final quote.
    public static func mismatch(_ reason: String?) -> Mismatch? {
        guard let reason,
              let regex = try? NSRegularExpression(pattern: #"Release edition '(.*?)' does not match the tracked edition '(.+)'\s*$"#),
              let m = regex.firstMatch(in: reason, range: NSRange(reason.startIndex..., in: reason)),
              let r1 = Range(m.range(at: 1), in: reason), let r2 = Range(m.range(at: 2), in: reason) else { return nil }
        return Mismatch(releaseEdition: String(reason[r1]), tracked: String(reason[r2]))
    }

    private static let stopTokens: Set<String> = [
        "4k", "uhd", "2160p", "1080p", "1080i", "720p", "576p", "480p",
        "web", "webdl", "webrip", "bluray", "blu", "bdrip", "brrip", "brip", "hdtv", "hdrip", "remux", "dvdrip", "dvd",
        "cam", "ts", "hdcam",
        "x264", "x265", "h264", "h265", "hevc", "avc", "xvid", "divx",
        "aac", "ac3", "eac3", "dts", "dd", "ddp", "truehd", "atmos", "flac", "mp3",
        "hdr", "hdr10", "dv", "proper", "repack",
    ]

    private static func isStop(_ token: String) -> Bool {
        let t = token.lowercased()
        return stopTokens.contains(t) || t.range(of: #"^\d{3,4}[pi]$"#, options: .regularExpression) != nil
    }

    /// The tokens between the release year (the last one before the quality
    /// block) and the first quality/source/codec token, at most eight.
    public static func term(_ releaseName: String?) -> String {
        guard let releaseName else { return "" }
        let tokens = releaseName.components(separatedBy: CharacterSet(charactersIn: ". _-")).filter { !$0.isEmpty }
        let stop = tokens.firstIndex(where: isStop) ?? tokens.count
        guard let year = tokens[..<stop].lastIndex(where: { $0.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) != nil })
        else { return "" }
        return tokens[(year + 1)..<stop].prefix(8).joined(separator: " ")
    }
}
