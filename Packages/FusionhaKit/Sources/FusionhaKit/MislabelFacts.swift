import Foundation

/// The mislabel facts grid behind "Why it's held" (the web's `MislabelFacts.tsx`
/// and `mislabel-format.ts`): what the release said, what the probe measured,
/// what is on disk, the release's CF and the outcome, as label/value rows.
public enum MislabelFacts {
    /// One row of the grid. `bad` marks the measured values drawn in red.
    public struct Row: Sendable, Equatable {
        public let label: String
        public let value: String
        public let bad: Bool
    }

    /// Formats named after the on-disk CF before "+N more".
    public static let maxFormats = 3

    /// −9245 / +1075 with a typographic minus.
    public static func signed(_ n: Int) -> String {
        n < 0 ? "−\(abs(n))" : n > 0 ? "+\(n)" : "0"
    }

    private static let ratios: [(String, Double)] = [
        ("4:3", 4.0 / 3), ("3:2", 3.0 / 2), ("16:10", 16.0 / 10), ("16:9", 16.0 / 9), ("21:9", 21.0 / 9),
    ]

    /// The nearest common aspect ratio within 3%, else nil.
    public static func aspectRatio(w: Int, h: Int) -> String? {
        guard w > 0, h > 0 else { return nil }
        let r = Double(w) / Double(h)
        return ratios.first { abs(r - $0.1) / $0.1 < 0.03 }?.0
    }

    public static func rows(_ d: HeldDetail, indexer: String?) -> [Row] {
        var says = d.claimedQuality ?? "unknown"
        if let group = d.releaseGroup { says += " · group \(group)" }
        if let indexer, !indexer.isEmpty { says += " · \(indexer)" }
        var out = [Row(label: "Release says", value: says, bad: false)]

        let res = d.probedResolution
        let ratio = res.flatMap { aspectRatio(w: $0.w, h: $0.h) }
        let bucket = d.probedResolutionBucket.map { "\($0)p" } ?? "?"
        let measured = [res.map { "\($0.w)×\($0.h)" }, "(\(bucket)\(ratio.map { ", \($0)" } ?? ""))"]
            .compactMap { $0 }.joined(separator: " ")
        out.append(Row(label: "Measured", value: "\(measured) · probed after download", bad: true))

        if let current = d.currentQuality {
            var disk = "\(current) · \(d.currentGroup ?? "no group") · CF \(signed(d.currentCf ?? 0))"
            let formats = d.currentFormats ?? []
            if !formats.isEmpty {
                let more = formats.count > maxFormats ? " +\(formats.count - maxFormats) more" : ""
                disk += " (matches \(formats.prefix(maxFormats).joined(separator: ", "))\(more))"
            }
            out.append(Row(label: "On disk now", value: disk, bad: false))
        }
        if let cf = d.candidateCf {
            out.append(Row(label: "Release CF",
                           value: "\(signed(cf)), which is why it was grabbed. Score was read from the name, not the file.",
                           bad: false))
        }
        out.append(Row(label: "Outcome",
                       value: d.currentQuality != nil ? "Not imported. Your existing file is untouched." : "Not imported.",
                       bad: false))
        return out
    }

    /// "TSRG has now mislabelled 4 releases here." (the proof strip).
    public static func proofSentence(group: String, count: Int) -> String {
        "\(group) has now mislabelled \(count) \(count == 1 ? "release" : "releases") here."
    }
}
