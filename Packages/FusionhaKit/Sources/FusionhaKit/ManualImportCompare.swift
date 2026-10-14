import Foundation

// What a row's file is, side by side with the name and with the file on disk.
// Ported from the web's `routes/manual-import/{capabilities,held-compare,
// which-file-rows,name-file-rows}.ts`.

public enum ManualImportCompare {
    private static let codec = ["hevc": "HEVC", "h264": "H.264", "h.264": "H.264", "av1": "AV1",
                                "vc1": "VC-1", "mpeg2video": "MPEG-2"]
    private static let nameCodec = ["HEVC": "H.265", "AVC": "H.264"]
    private static let audio = ["eac3": "DDP", "ac3": "DD", "truehd": "TrueHD", "dts": "DTS", "aac": "AAC",
                                "flac": "FLAC", "opus": "Opus", "mp3": "MP3"]
    private static let channels = [1: "1.0", 2: "2.0", 3: "2.1", 6: "5.1", 7: "6.1", 8: "7.1"]
    private static let drRank = ["SDR": 0, "HLG": 1, "HDR10": 2, "HDR10+": 3, "DV": 4]
    private static let langShort = ["English": "EN", "Spanish": "ES", "French": "FR", "German": "DE",
                                    "Japanese": "JA", "Italian": "IT", "Portuguese": "PT", "Unknown": "?"]
    private static let container = ["matroska,webm": "MKV", "mov,mp4,m4a,3gp,3g2,mj2": "MP4", "mpegts": "TS", "avi": "AVI"]

    // MARK: Probe text

    public static func dynamicRange(_ p: ManualImportProbe) -> String {
        let hdr = p.hdrFormat ?? ""
        if hdr.hasPrefix("dv") { return "DV" }
        switch hdr {
        case "hdr10+": return "HDR10+"
        case "hdr10": return "HDR10"
        case "hlg": return "HLG"
        default: return "SDR"
        }
    }

    public static func codecName(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        return codec[raw.lowercased()] ?? raw.uppercased()
    }

    public static func video(_ p: ManualImportProbe) -> String {
        let name = (codecName(p.videoCodec) ?? "") + ((p.bitDepth ?? 0) >= 10 ? " 10-bit" : "")
        return [name, p.encodeLibrary ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The probe's audio label, else codec + channel layout.
    public static func audioText(_ p: ManualImportProbe) -> String {
        if let label = p.audioLabel?.trimmingCharacters(in: .whitespaces), !label.isEmpty { return label }
        let c = p.audioCodec ?? ""
        let ch = p.audioChannels.map { channels[$0] ?? "\($0)ch" } ?? ""
        return [audio[c.lowercased()] ?? c.uppercased(), ch].filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func subs(_ langs: [String]) -> String {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for l in langs { if counts[l] == nil { order.append(l) }; counts[l, default: 0] += 1 }
        return order.map { "\(langShort[$0] ?? $0)\(counts[$0]! > 1 ? " ×\(counts[$0]!)" : "")" }.joined(separator: " · ")
    }

    static func gb(_ bytes: Double) -> String { String(format: "%.1f GB", bytes / 1e9) }

    /// The collapsed row's dim line: video · audio · group · service · probe state.
    public static func summaryLine(_ row: ManualImportRow) -> String {
        let p = row.probe
        var parts: [String] = []
        if let p, p.isOK {
            let diffs = Dictionary((row.nameVsFile ?? []).map { ($0.field, $0) }, uniquingKeysWith: { a, _ in a })
            if diffs["resolution"] != nil, let h = p.height { parts.append("\(h)p") }
            else if (row.match.itemId == nil || row.parsed.resolution == nil), let w = p.width, let h = p.height { parts.append("\(w)×\(h)") }
            let dr = dynamicRange(p)
            if dr == "DV" { parts.append(p.dvProfile.map { "DV P\($0)" } ?? "DV") }
            if dr != "DV" || p.hdrFormat?.contains("hdr10") == true { parts.append(dr == "DV" ? "HDR10" : dr) }
            if let c = codecName(p.videoCodec) { parts.append(c) }
            if p.audioCodec != nil || p.audioLabel != nil { parts.append(audioText(p)) }
        } else {
            parts += (row.parsed.dynamicRange ?? []).map { $0 == "HDR10PLUS" ? "HDR10+" : $0 }
            if let vc = row.parsed.videoCodec { parts.append(nameCodec[vc] ?? vc) }
            if let a = row.parsed.audioLabel { parts.append(a) }
        }
        if let g = row.parsed.releaseGroup { parts.append(g) }
        if let s = row.parsed.streamingService { parts.append(s) }
        switch p?.state {
        case "pending": parts.append("checking…")
        case "failed", "unsupported": parts.append("couldn’t read the file")
        default: break
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Name vs file

    public struct NameFileRow: Hashable, Sendable {
        public let label: String
        public let name: String?
        public let file: String
        public let bad: Bool
    }

    /// The opened row's "Name vs file" table.
    public static func nameFileRows(_ row: ManualImportRow) -> [NameFileRow] {
        guard let p = row.probe, p.isOK else {
            return [NameFileRow(label: "File", name: nil,
                                file: row.probe?.isPending == true ? "probing…" : "probe failed · nothing measured", bad: false)]
        }
        var rows: [NameFileRow] = []
        let m = row.measured
        if let w = p.width, let h = p.height {
            let cls = m?.mislabeled == true ? (m?.resolutionBucket.map { " · \($0)p class" } ?? "") : ""
            rows.append(.init(label: "Resolution", name: row.parsed.resolution.map { "\($0)p" },
                              file: "\(w)×\(h)\(cls)", bad: m?.mislabeled == true))
        }
        rows.append(.init(label: "Dynamic range", name: (row.parsed.dynamicRange ?? []).first,
                          file: dynamicRange(p) + (p.dvProfile.map { " · profile \($0)" } ?? ""),
                          bad: (row.nameVsFile ?? []).contains { $0.field == "hdr" }))
        if let c = codecName(p.videoCodec) {
            rows.append(.init(label: "Video", name: row.parsed.videoCodec.map { nameCodec[$0] ?? $0 },
                              file: c + ((p.bitDepth ?? 0) >= 10 ? " 10-bit" : ""),
                              bad: (row.nameVsFile ?? []).contains { $0.field == "video_codec" }))
        }
        if p.audioCodec != nil {
            rows.append(.init(label: "Audio", name: row.parsed.audioLabel, file: audioText(p),
                              bad: (row.nameVsFile ?? []).contains { $0.field == "audio" }))
        }
        if let subsList = p.subtitleLanguages, !subsList.isEmpty {
            rows.append(.init(label: "Subtitles", name: nil, file: subs(subsList), bad: false))
        }
        if let c = p.container {
            rows.append(.init(label: "Container", name: nil, file: container[c] ?? c.uppercased(), bad: false))
        }
        return rows
    }

    // MARK: Which file stays?

    public struct WhichRow: Hashable, Sendable {
        public enum Tone: Sendable { case up, down, same }
        public let label: String
        public let current: String
        public let incoming: String
        public let tone: Tone
        /// Shown before "Show all".
        public let changed: Bool
    }

    /// Each attribute for the file on disk and for this file, and which way this
    /// file moves it. Nil without a file on disk; empty until both are measured.
    public static func whichFileRows(_ row: ManualImportRow) -> [WhichRow]? {
        guard let cur = row.existingFile else { return nil }
        guard let c = cur.probe, c.isOK, let inc = row.probe, inc.isOK else { return [] }
        func tone(_ a: Double, _ b: Double) -> WhichRow.Tone { a > b ? .up : a < b ? .down : .same }
        func r(_ label: String, _ current: String, _ incoming: String, _ t: WhichRow.Tone) -> WhichRow {
            WhichRow(label: label, current: current, incoming: incoming, tone: t, changed: current != incoming || t != .same)
        }
        let area = { (p: ManualImportProbe) in Double((p.width ?? 0) * (p.height ?? 0)) }
        let lost = (c.audioLanguages ?? []).filter { !(inc.audioLanguages ?? []).contains($0) }
        let added = (inc.audioLanguages ?? []).filter { !(c.audioLanguages ?? []).contains($0) }
        let subsLost = (c.subtitleLanguages ?? []).filter { !(inc.subtitleLanguages ?? []).contains($0) }
        let incomingCf = cur.verdict?.provenCf ?? row.incomingCf?.score ?? 0
        let curCf = cur.cfScore ?? 0
        let cfGap = cur.verdict.map { $0.claimedCf != $0.provenCf } ?? false
        var rows = [
            r("Resolution", "\(c.width ?? 0)×\(c.height ?? 0)", "\(inc.width ?? 0)×\(inc.height ?? 0)", tone(area(inc), area(c))),
            r("Dynamic range", dynamicRange(c), dynamicRange(inc),
              tone(Double(drRank[dynamicRange(inc)] ?? 0), Double(drRank[dynamicRange(c)] ?? 0))),
            r("Video", video(c), video(inc), .same),
            r("Audio", audioText(c), audioText(inc), .same),
            r("Audio languages", (c.audioLanguages ?? []).joined(separator: ", "),
              (inc.audioLanguages ?? []).joined(separator: ", ").ifEmpty("not measured"),
              !lost.isEmpty ? .down : !added.isEmpty ? .up : .same),
            r("Subtitles", subs(c.subtitleLanguages ?? []).ifEmpty("—"), subs(inc.subtitleLanguages ?? []).ifEmpty("—"),
              subsLost.isEmpty ? .same : .down),
            r("Size", gb(cur.size ?? 0), gb(row.size), .same),
        ]
        let cf = WhichRow(label: "Custom formats", current: String(curCf), incoming: String(incomingCf),
                          tone: tone(Double(incomingCf), Double(curCf)), changed: cfGap || incomingCf != curCf)
        rows.append(cf)
        return rows
    }
}

extension String {
    fileprivate func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
