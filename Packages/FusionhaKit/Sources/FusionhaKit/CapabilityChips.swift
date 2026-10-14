import Foundation

// Release-fact chips, as the web's `manual-import/capabilities.ts` and the
// queue card's `release-facts.ts`: one chip per fact, built from what the
// release name claims and what the probe measured. A probed chip carries a
// pulse, a name-only chip a dashed tag, and a chip where name and file
// disagree turns amber with the claimed value struck through.

/// One value inside a chip.
public struct ChipSegment: Sendable, Hashable {
    /// p = probed · n = from the name · d = name and file disagree · x = probe state.
    public enum Kind: Sendable, Hashable { case probed, named, differs, state }
    public let kind: Kind
    public let text: String
    /// The claimed value a `differs` segment replaces (drawn struck through).
    public let from: String?
    public let title: String

    public init(_ kind: Kind, _ text: String, from: String? = nil, title: String) {
        self.kind = kind
        self.text = text
        self.from = from
        self.title = title
    }
}

public struct ChipModel: Sendable, Hashable {
    /// What the chip's glyph and border say: probed, named or a probe state.
    public enum Base: Sendable, Hashable { case probed, named, state }
    public let base: Base?
    public let hasDiff: Bool
    public let segments: [ChipSegment]
    public var tooltip: String

    public init(_ segments: [ChipSegment]) {
        let kinds = Set(segments.map(\.kind))
        self.segments = segments
        hasDiff = kinds.contains(.differs)
        base = segments.isEmpty ? nil : kinds.contains(.probed) ? .probed : kinds.contains(.named) ? .named : .state
        tooltip = segments.map { s in
            switch s.kind {
            case .differs: return "\(s.from ?? "") → \(s.text) (\(s.title))"
            case .probed: return "\(s.text) (probed)"
            case .named: return "\(s.text) (name)"
            case .state: return s.text
            }
        }.joined(separator: " · ")
    }

    /// The chip's text as one line ("2560×1440 · DV · HDR · H.265").
    public var text: String {
        segments.map { s in s.from.map { "\($0)→\(s.text)" } ?? s.text }.joined(separator: " · ")
    }
}

/// One fact chip on a queue card.
public struct ReleaseFactChip: Sendable, Hashable, Identifiable {
    public let key: String
    /// Screen-reader prefix ("Video").
    public let label: String
    public let model: ChipModel
    public var id: String { key }
}

public enum CapabilityChips {
    public static let probedTitle = "Probed from the file"
    public static let namedTitle = "From the release name, unverified"

    /// A name-vs-file disagreement the server proved (resolution, HDR, codec, audio).
    public struct Diff: Sendable, Hashable {
        public let field: String
        public let name: String
        public let file: String
    }

    private static let codec = ["hevc": "HEVC", "h264": "H.264", "h.264": "H.264", "av1": "AV1",
                                "vc1": "VC-1", "mpeg2video": "MPEG-2"]
    private static let nameCodec = ["HEVC": "H.265", "AVC": "H.264", "AV1": "AV1", "VC-1": "VC-1",
                                    "MPEG-2": "MPEG-2", "XviD": "XviD"]
    private static let audio = ["eac3": "DDP", "ac3": "DD", "truehd": "TrueHD", "dts": "DTS", "aac": "AAC",
                                "flac": "FLAC", "opus": "Opus", "mp3": "MP3"]
    private static let channels = [1: "1.0", 2: "2.0", 3: "2.1", 6: "5.1", 7: "6.1", 8: "7.1"]

    static func stateSegment(_ probe: ManualImportProbe?) -> ChipSegment? {
        switch probe?.state {
        case "failed", "unsupported":
            return ChipSegment(.state, "Probe failed", title: "Nothing was measured; the other values come from the name only")
        case "pending":
            return ChipSegment(.state, "Probing…", title: "Probe in flight")
        default:
            return nil
        }
    }

    /// The video values the release name claims (HDR/DV tags, codec), unverified.
    static func nameVideo(_ parsed: ReleaseFacts) -> [ChipSegment] {
        let dr = (parsed.dynamicRange ?? []).map { ChipSegment(.named, $0 == "HDR10PLUS" ? "HDR10+" : $0, title: namedTitle) }
        let vc = parsed.videoCodec.map { [ChipSegment(.named, nameCodec[$0] ?? $0, title: namedTitle)] } ?? []
        return dr + vc
    }

    /// Video chip: probed values lead, name values fill in; disagreements
    /// come from the server's proof (`diffs`).
    static func video(_ parsed: ReleaseFacts, probe: ManualImportProbe?, diffs: [Diff], matched: Bool) -> ChipModel {
        guard let p = probe, p.isOK else {
            return ChipModel((stateSegment(probe).map { [$0] } ?? []) + nameVideo(parsed))
        }
        let byField = Dictionary(diffs.map { ($0.field, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [ChipSegment] = []
        if let res = byField["resolution"], let h = p.height {
            out.append(ChipSegment(.differs, "\(h)p", from: res.name, title: "Name: \(res.name) · File: \(res.file)"))
        } else if !matched || parsed.resolution == nil, let w = p.width, let h = p.height {
            out.append(ChipSegment(.probed, "\(w)×\(h)", title: probedTitle))
        }
        let hdr = p.hdrFormat?.lowercased()
        if hdr?.hasPrefix("dv") == true {
            out.append(ChipSegment(.probed, "DV", title: p.dvProfile.map { "Dolby Vision profile \($0)" } ?? probedTitle))
        }
        let hdrText: String? = hdr.map { h in
            h.contains("hdr10+") ? "HDR10+" : h.contains("hdr10") ? "HDR10" : h == "hlg" ? "HLG" : nil
        } ?? "SDR"
        if let d = byField["hdr"] {
            out.append(ChipSegment(.differs, hdrText ?? "SDR", from: d.name, title: "Name says \(d.name); the probe found \(d.file)"))
        } else if let hdrText {
            out.append(ChipSegment(.probed, hdrText, title: hdrText == "SDR" ? "No HDR metadata" : probedTitle))
        }
        let measured = p.videoCodec.map { codec[$0.lowercased()] ?? $0.uppercased() }
        if let d = byField["video_codec"] {
            out.append(ChipSegment(.differs, measured ?? d.file, from: nameCodec[d.name] ?? d.name, title: "Name and file codecs differ"))
        } else if let measured {
            out.append(ChipSegment(.probed, measured, title: probedTitle))
        }
        return ChipModel(out)
    }

    /// One audio label: the probe's own label, else codec + channels.
    static func audioText(_ p: ManualImportProbe) -> String {
        if let label = p.audioLabel?.trimmingCharacters(in: .whitespaces), !label.isEmpty { return label }
        let c = p.audioCodec ?? ""
        let ch = p.audioChannels.map { channels[$0] ?? "\($0)ch" } ?? ""
        return [audio[c.lowercased()] ?? c.uppercased(), ch].filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func audio(_ parsed: ReleaseFacts, probe: ManualImportProbe?, diffs: [Diff]) -> ChipModel {
        guard let p = probe, p.isOK, p.audioCodec != nil || p.audioLabel != nil else {
            return ChipModel(parsed.audioLabel.map { [ChipSegment(.named, $0, title: namedTitle)] } ?? [])
        }
        let text = audioText(p)
        if let d = diffs.first(where: { $0.field == "audio" }) {
            return ChipModel([ChipSegment(.differs, text, from: d.name, title: "Name and file audio differ")])
        }
        let codec = (p.audioCodec ?? "").uppercased()
        return ChipModel([ChipSegment(.probed, text, title: codec + (p.audioChannels.map { " · \($0)ch" } ?? ""))])
    }
}

extension CapabilityChips {
    /// The name-vs-file disagreements a hold proved (resolution, HDR).
    static func heldDiffs(_ d: HeldDetail?) -> [Diff] {
        guard let d else { return [] }
        var out: [Diff] = []
        if d.mislabeled == true, let claimed = d.claimedResolution, let res = d.probedResolution, res.w > 0, res.h > 0 {
            out.append(Diff(field: "resolution", name: "\(claimed)p", file: "\(res.w)×\(res.h)"))
        }
        if d.kind == "mislabeled_hdr", let claim = d.claimedHdr, !claim.isEmpty {
            out.append(Diff(field: "hdr", name: claim.joined(separator: " "), file: d.probedHdr ?? "none"))
        }
        return out
    }

    /// A held row's quality: the name's, or "claimed → graded" when the probe disproved it.
    static func queueQuality(_ item: QueueItem, _ parsed: ReleaseFacts) -> ChipModel {
        if let d = item.heldDetail, d.mislabeled == true, let claimed = d.claimedQuality,
           let probed = d.probedQuality, claimed != probed {
            let a = DetailText.quality(claimed), b = DetailText.quality(probed)
            return ChipModel([ChipSegment(.differs, b, from: a, title: "Name says \(a) · the file grades as \(b)")])
        }
        return ChipModel(parsed.quality.map { [ChipSegment(.named, DetailText.quality($0), title: namedTitle)] } ?? [])
    }

    /// An older hold kept only the frame size: the size is measured, the HDR /
    /// DV / codec tags stay "from the name" rather than reading as probed SDR.
    static func queueVideo(_ item: QueueItem, _ parsed: ReleaseFacts, diffs: [Diff]) -> ChipModel {
        guard let p = item.probe, p.isOK, p.videoCodec == nil else {
            return video(parsed, probe: item.probe, diffs: diffs, matched: true)
        }
        var size: [ChipSegment] = []
        if let res = diffs.first(where: { $0.field == "resolution" }), let h = p.height {
            size.append(ChipSegment(.differs, "\(h)p", from: res.name, title: "Name: \(res.name) · File: \(res.file)"))
        } else if let w = p.width, let h = p.height {
            size.append(ChipSegment(.probed, "\(w)×\(h)", title: probedTitle))
        }
        return ChipModel(size + nameVideo(parsed))
    }

    /// Every chip for one queue row, in the web's order: quality, mixed (a
    /// held pack whose files differ), video, audio, group, languages,
    /// revision. Empty when the row has no parsed release name.
    public static func queueFacts(_ item: QueueItem) -> [ReleaseFactChip] {
        guard let parsed = item.parsed else { return [] }
        let diffs = heldDiffs(item.heldDetail)
        var quality = queueQuality(item, parsed)
        var facts: [ReleaseFactChip] = [ReleaseFactChip(key: "quality", label: "Quality", model: quality)]
        for m in PackDecisions.mixedFacts(item.packMixed, parsed: parsed) {
            var model = ChipModel([ChipSegment(.differs, m.text, title: m.detail)])
            model.tooltip = m.detail
            facts.append(ReleaseFactChip(key: "mixed-\(m.key)", label: m.accessibilityLabel, model: model))
        }
        facts.append(ReleaseFactChip(key: "video", label: "Video", model: queueVideo(item, parsed, diffs: diffs)))
        facts.append(ReleaseFactChip(key: "audio", label: "Audio", model: audio(parsed, probe: item.probe, diffs: diffs)))
        let groupParts = [parsed.releaseGroup, parsed.streamingService].compactMap { $0 }.filter { !$0.isEmpty }
        if !groupParts.isEmpty {
            var model = ChipModel(groupParts.map { ChipSegment(.named, $0, title: namedTitle) })
            if let release = item.releaseTitle { model.tooltip = "Release: \(release)" }
            facts.append(ReleaseFactChip(key: "group", label: "Release group", model: model))
        } else if let release = item.releaseTitle {
            quality.tooltip += " · Release: \(release)"
            facts[0] = ReleaseFactChip(key: "quality", label: "Quality", model: quality)
        }
        let langs = (parsed.languages ?? []).filter { $0 != "Unknown" && $0 != "English" }
        if !langs.isEmpty {
            facts.append(ReleaseFactChip(key: "languages", label: "Languages",
                                         model: ChipModel(langs.map { ChipSegment(.named, $0, title: namedTitle) })))
        }
        if let revision = parsed.isRepack == true ? "REPACK" : parsed.isProper == true ? "PROPER" : nil {
            facts.append(ReleaseFactChip(key: "revision", label: "Revision",
                                         model: ChipModel([ChipSegment(.named, revision, title: namedTitle)])))
        }
        return facts.filter { $0.model.base != nil }
    }
}
