import Foundation

// The season page's file facts (owner option B, 2026-11-06): each episode
// row's badge line carries small outline chips (source + resolution, audio,
// release group) and its size. What the season's files share is said once
// under the season header; a row then shows only its size plus any chip
// that differs from that shared value (drawn in orange).

/// One fact chip on an episode row or under the season header.
public struct FileFactChip: Sendable, Hashable, Identifiable {
    /// The chips' order on the line. HDR / Dolby Vision would sit after
    /// audio once the server sends it; until then there is no slot.
    public enum Kind: Int, Sendable, CaseIterable {
        case source, audio, group

        /// VoiceOver's word for the chip.
        public var spoken: String {
            switch self {
            case .source: return "quality"
            case .audio: return "audio"
            case .group: return "group"
            }
        }
    }

    public let kind: Kind
    public let text: String
    /// Not the value the rest of the season shares.
    public let differs: Bool
    public var id: Kind { kind }

    public init(kind: Kind, text: String, differs: Bool = false) {
        self.kind = kind
        self.text = text
        self.differs = differs
    }
}

/// One file's facts line: the chips to show and its size.
public struct FileFactsLine: Sendable, Hashable {
    public let chips: [FileFactChip]
    /// Bytes on disk; nil when the server sent none.
    public let bytes: Double?

    public init(chips: [FileFactChip], bytes: Double?) {
        self.chips = chips
        self.bytes = bytes
    }

    /// "2.4 GB", nil without a size.
    public var size: String? { bytes.map { DetailText.bytes($0) } }
}

/// What a season's on-disk files in one version share, and each file's line.
public struct SeasonFileFacts: Sendable, Hashable {
    /// The shared chips, in order (never `differs`).
    public let shared: [FileFactChip]
    public let fileCount: Int
    public let bytes: Double

    public init(files: [MovieFile]) {
        fileCount = files.count
        bytes = files.compactMap(\.size).filter { $0.isFinite && $0 > 0 }.reduce(0, +)
        shared = FileFactChip.Kind.allCases.compactMap { kind in
            Self.sharedValue(files.map { Self.value(kind, of: $0) }).map { FileFactChip(kind: kind, text: $0) }
        }
    }

    /// "32.4 GB", nil when nothing has a size.
    public var totalSize: String? { bytes > 0 ? DetailText.bytes(bytes) : nil }

    /// The row's line: every fact not shared, marked `differs` where the
    /// season shares another value for it. A fact the file lacks (audio not
    /// analysed yet) shows no chip.
    public func line(for file: MovieFile) -> FileFactsLine {
        let common = Dictionary(shared.map { ($0.kind, $0.text) }, uniquingKeysWith: { a, _ in a })
        let chips: [FileFactChip] = FileFactChip.Kind.allCases.compactMap { kind in
            guard let text = Self.value(kind, of: file), common[kind] != text else { return nil }
            return FileFactChip(kind: kind, text: text, differs: common[kind] != nil)
        }
        let size = file.size.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        return FileFactsLine(chips: chips, bytes: size)
    }

    /// The value most files that have one agree on: at least two files, and
    /// more than half of those with a value. nil when nothing is shared.
    public static func sharedValue(_ values: [String?]) -> String? {
        let known = values.compactMap { $0 }
        guard known.count >= 2 else { return nil }
        var counts: [String: Int] = [:]
        for value in known { counts[value, default: 0] += 1 }
        guard let top = counts.max(by: { $0.value < $1.value }), top.value * 2 > known.count else { return nil }
        return top.key
    }

    /// A chip's text from the server's fields only (never the filename).
    public static func value(_ kind: FileFactChip.Kind, of file: MovieFile) -> String? {
        switch kind {
        case .source: return FileNameFacts.qualityText(file.quality)
        case .audio: return file.probedAudio
        case .group:
            guard let group = file.releaseGroup?.trimmingCharacters(in: .whitespaces), !group.isEmpty else { return nil }
            return group
        }
    }

    /// The facts of one season per version: versions with no file on disk
    /// are left out.
    public static func perVersion(_ season: Season, editions: [DetailEdition]) -> [SeasonVersionFileFacts] {
        editions.compactMap { edition in
            let files = season.episodes.compactMap { $0.file(for: edition.id) }
            guard !files.isEmpty else { return nil }
            return SeasonVersionFileFacts(editionId: edition.id, tier: edition.tier, facts: SeasonFileFacts(files: files))
        }
    }
}

/// One version's share of a season's facts.
public struct SeasonVersionFileFacts: Sendable, Hashable, Identifiable {
    public let editionId: Int
    public let tier: QualityTier
    public let facts: SeasonFileFacts
    public var id: Int { editionId }

    public init(editionId: Int, tier: QualityTier, facts: SeasonFileFacts) {
        self.editionId = editionId
        self.tier = tier
        self.facts = facts
    }
}

/// One spoken sentence per facts line: "2.4 GB, quality WEBRip 1080p,
/// differs from the season, group NTb, differs from the season".
public enum FileFactsSpeech {
    public static func line(_ chips: [FileFactChip], size: String?) -> String {
        var parts = size.map { [$0] } ?? []
        for chip in chips {
            parts.append("\(chip.kind.spoken) \(chip.text)" + (chip.differs ? ", differs from the season" : ""))
        }
        return parts.joined(separator: ", ")
    }
}
