import Foundation

/// The media facts a release filename carries, for a file the server has not
/// probed yet: `…[WEBRip-1080p][AAC 2.0][x265]-TiKos.mkv` reads as WEBRip,
/// 1080p, x265, AAC 2.0, TiKos. Display only; the server's own facts
/// (quality code, probe, release group) always win when present.
public struct FileNameFacts: Sendable, Hashable {
    public var source: String?
    public var resolution: String?
    public var videoCodec: String?
    public var audio: String?
    public var releaseGroup: String?

    public init(source: String? = nil, resolution: String? = nil, videoCodec: String? = nil,
                audio: String? = nil, releaseGroup: String? = nil) {
        self.source = source
        self.resolution = resolution
        self.videoCodec = videoCodec
        self.audio = audio
        self.releaseGroup = releaseGroup
    }

    /// `WEBRip 1080p`, `1080p`, `HDTV`, or nil.
    public var quality: String? {
        let parts = [source, resolution].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Parses a path or a bare filename.
    public static func parse(_ path: String) -> FileNameFacts {
        let name = stem(of: path)
        var facts = FileNameFacts()
        var lastFactEnd = -1
        func note(_ r: Range<String.Index>?) {
            guard let r else { return }
            lastFactEnd = max(lastFactEnd, name.distance(from: name.startIndex, to: r.upperBound))
        }

        if let hit = firstMatch(sources, in: name) { facts.source = hit.label; note(hit.range) }
        if let hit = firstMatch(resolutions, in: name) { facts.resolution = hit.label; note(hit.range) }
        if let hit = firstMatch(videoCodecs, in: name) { facts.videoCodec = hit.label; note(hit.range) }

        let codec = firstMatch(audioCodecs, in: name)
        let atmos = range(of: #"(?<![A-Za-z0-9])atmos(?![A-Za-z])"#, in: name)
        note(codec?.range)
        note(atmos)
        var audioParts: [String] = []
        if let codec { audioParts.append(codec.label) }
        if atmos != nil { audioParts.append("Atmos") }
        // Channels sit right after the codec (`AAC 2.0`, `AAC-2.0`, `DDP5.1`),
        // so a title's numbers never read as channels.
        if let codec,
           let ch = captures(#"^[ ._-]?([1-7])[ .]([01])(?![0-9])"#, in: String(name[codec.range.upperBound...])) {
            audioParts.insert("\(ch.0).\(ch.1)", at: 1)
        }
        if !audioParts.isEmpty { facts.audio = audioParts.joined(separator: " ") }

        facts.releaseGroup = group(in: name, after: lastFactEnd)
        return facts
    }

    // MARK: - Pieces

    /// The filename without folders or a short extension.
    static func stem(of path: String) -> String {
        let base = path.split(separator: "/", omittingEmptySubsequences: true).last.map(String.init) ?? path
        guard let dot = base.lastIndex(of: ".") else { return base }
        let ext = base[base.index(after: dot)...]
        let isExt = (1...4).contains(ext.count) && ext.allSatisfy { $0.isLetter || $0.isNumber }
            && ext.contains(where: { $0.isLetter })
        return isExt ? String(base[..<dot]) : base
    }

    /// `-Group` at the very end, only after at least one recognised fact, so
    /// a hyphenated title (`Spider-Man`) is never taken for a group.
    static func group(in name: String, after factEnd: Int) -> String? {
        guard factEnd >= 0,
              let r = range(of: #"-([A-Za-z0-9][A-Za-z0-9_]*)$"#, in: name) else { return nil }
        let start = name.distance(from: name.startIndex, to: r.lowerBound)
        guard start >= factEnd else { return nil }
        let value = String(name[name.index(after: r.lowerBound)...])
        let lower = value.lowercased()
        if ["dl", "rip", "hd", "web"].contains(lower) { return nil }
        if firstMatch(resolutions + videoCodecs + audioCodecs, in: value) != nil { return nil }
        return value
    }

    private typealias Rule = (pattern: String, label: String)

    private static let sources: [Rule] = [
        (#"(?<![A-Za-z0-9])remux(?![A-Za-z])"#, "Remux"),
        (#"(?<![A-Za-z0-9])web[ ._-]?dl(?![A-Za-z])"#, "WEB-DL"),
        (#"(?<![A-Za-z0-9])web[ ._-]?rip(?![A-Za-z])"#, "WEBRip"),
        (#"(?<![A-Za-z0-9])(blu[ ._-]?ray|bdrip|brrip)(?![A-Za-z])"#, "BluRay"),
        (#"(?<![A-Za-z0-9])hdtv(?![A-Za-z])"#, "HDTV"),
        (#"(?<![A-Za-z0-9])dvd(rip)?(?![A-Za-z])"#, "DVD"),
    ]

    private static let resolutions: [Rule] = [
        (#"(?<![0-9])2160[pi](?![A-Za-z0-9])"#, "2160p"),
        (#"(?<![A-Za-z0-9])4k(?![A-Za-z0-9])"#, "2160p"),
        (#"(?<![0-9])1080[pi](?![A-Za-z0-9])"#, "1080p"),
        (#"(?<![0-9])720p(?![A-Za-z0-9])"#, "720p"),
        (#"(?<![0-9])576p(?![A-Za-z0-9])"#, "576p"),
        (#"(?<![0-9])480p(?![A-Za-z0-9])"#, "480p"),
    ]

    private static let videoCodecs: [Rule] = [
        (#"(?<![A-Za-z0-9])x\.?265(?![0-9])"#, "x265"),
        (#"(?<![A-Za-z0-9])x\.?264(?![0-9])"#, "x264"),
        (#"(?<![A-Za-z0-9])h\.?265(?![0-9])"#, "h265"),
        (#"(?<![A-Za-z0-9])h\.?264(?![0-9])"#, "h264"),
        (#"(?<![A-Za-z0-9])hevc(?![A-Za-z])"#, "HEVC"),
        (#"(?<![A-Za-z0-9])avc(?![A-Za-z])"#, "h264"),
        (#"(?<![A-Za-z0-9])av1(?![0-9])"#, "AV1"),
    ]

    private static let audioCodecs: [Rule] = [
        (#"(?<![A-Za-z0-9])truehd(?![A-Za-z])"#, "TrueHD"),
        (#"(?<![A-Za-z0-9])dts[ ._-]?hd(?![A-Za-z])"#, "DTS-HD"),
        (#"(?<![A-Za-z0-9])dts(?![A-Za-z])"#, "DTS"),
        (#"(?<![A-Za-z0-9])e[ ._-]?ac[ ._-]?3(?![0-9])"#, "EAC3"),
        (#"(?<![A-Za-z0-9])(ddp|dd\+)"#, "DDP"),
        (#"(?<![A-Za-z0-9])ac[ ._-]?3(?![0-9])"#, "AC3"),
        (#"(?<![A-Za-z0-9])dd(?=[ .]?[1-7][ .][01])"#, "AC3"),
        (#"(?<![A-Za-z0-9])aac(?![A-Za-z])"#, "AAC"),
        (#"(?<![A-Za-z0-9])flac(?![A-Za-z])"#, "FLAC"),
        (#"(?<![A-Za-z0-9])opus(?![A-Za-z])"#, "Opus"),
    ]

    // MARK: - Regex helpers

    private static func firstMatch(_ rules: [Rule], in text: String) -> (label: String, range: Range<String.Index>)? {
        for rule in rules {
            if let r = range(of: rule.pattern, in: text) { return (rule.label, r) }
        }
        return nil
    }

    private static func range(of pattern: String, in text: String) -> Range<String.Index>? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re.firstMatch(in: text, options: [], range: ns) else { return nil }
        return Range(m.range, in: text)
    }

    private static func captures(_ pattern: String, in text: String) -> (String, String)? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re.firstMatch(in: text, options: [], range: ns), m.numberOfRanges >= 3,
              let a = Range(m.range(at: 1), in: text), let b = Range(m.range(at: 2), in: text) else { return nil }
        return (String(text[a]), String(text[b]))
    }
}

// MARK: - Quality codes

extension FileNameFacts {
    /// A server quality code as the facts line says it: `WEBRIP_1080P` →
    /// `WEBRip 1080p`, `REMUX_2160P` → `Remux 2160p`. Unknown → nil.
    public static func qualityText(_ code: String?) -> String? {
        guard let code, !code.isEmpty, code != "UNKNOWN" else { return nil }
        let parts = code.split(separator: "_").map(String.init)
        let sourceNames = ["WEBRIP": "WEBRip", "WEBDL": "WEB-DL", "BLURAY": "BluRay", "REMUX": "Remux", "HDTV": "HDTV"]
        if parts.count == 2, let source = sourceNames[parts[0]], parts[1].hasSuffix("P") {
            return "\(source) \(parts[1].lowercased())"
        }
        return DetailText.quality(code)
    }

    /// The vertical lines of a resolution (`1080p` → 1080), or nil.
    public static func lines(_ resolution: String?) -> Int? {
        guard let resolution else { return nil }
        let digits = resolution.prefix { $0.isNumber }
        return Int(digits)
    }

    /// Whether a file's resolution sits below its version's tier (a 720p file
    /// inside the 1080p version). Unknown resolutions are never flagged.
    public static func isBelow(resolution: String?, tier: QualityTier) -> Bool {
        guard let lines = lines(resolution) else { return false }
        return lines < (tier == .hd ? 1080 : 2160)
    }
}

// MARK: - Probe first (fusionha 0.4.236)

extension MovieFile {
    /// `h265`: the server's probed video codec, nil when unprobed.
    public var probedVideo: String? { Self.text(videoCodec) }

    /// `AAC 2.0`: the server's probed audio codec and channels, nil when unprobed.
    public var probedAudio: String? {
        guard let codec = Self.text(audioCodec) else { return nil }
        return [codec, Self.text(audioChannels)].compactMap { $0 }.joined(separator: " ")
    }

    private static func text(_ value: String?) -> String? {
        guard let t = value?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return t
    }
}

extension FileNameFacts {
    /// The Files tab's video and audio facts: the server's probe fields first,
    /// then the probe read on the device (an older server), then the name.
    public static func media(for file: MovieFile, probeVideo: String? = nil, probeAudio: String? = nil,
                             name: FileNameFacts) -> (video: String?, audio: String?) {
        (file.probedVideo ?? probeVideo ?? name.videoCodec, file.probedAudio ?? probeAudio ?? name.audio)
    }
}
