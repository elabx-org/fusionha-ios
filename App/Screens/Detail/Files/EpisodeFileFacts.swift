import Foundation
import FusionhaKit

/// What one episode file is, in words: the server's facts (quality code,
/// probe, release group) first, the filename's where the server has none.
struct EpisodeFileFacts {
    let quality: String?
    let video: String?
    let audio: String?
    let languages: String?
    let group: String?
    let size: String
    let length: String?
    /// Below its version's tier (a 720p file in the 1080p version).
    let belowTier: Bool
    let deadLink: Bool
    let analysing: Bool

    init(file: MovieFile, tier: QualityTier) {
        let probe = file.mediaInfo?.probe
        let serverQuality = FileNameFacts.qualityText(file.quality)
        let serverVideo = DetailMediaFacts.codec(probe)
        let serverAudio = DetailMediaFacts.audio(probe)
        let serverGroup = file.releaseGroup.flatMap { $0.isEmpty ? nil : $0 }
        // Parse the name only when a fact is missing (never for probed files).
        let needsName = serverQuality == nil || serverVideo == nil || serverAudio == nil || serverGroup == nil
        let name = needsName ? FileNameFacts.parse(file.relativePath ?? file.sceneName ?? "") : FileNameFacts()

        quality = serverQuality ?? name.quality
        let range = DetailMediaFacts.range(probe).flatMap { $0 == "SDR" ? nil : $0 }
        let codec = serverVideo ?? name.videoCodec
        let videoParts = [codec, range].compactMap { $0 }
        video = videoParts.isEmpty ? nil : videoParts.joined(separator: " ")
        audio = serverAudio ?? name.audio
        let named = (file.languages ?? []).filter { !$0.isEmpty }
        languages = named.isEmpty ? DetailMediaFacts.languages(probe) : named.joined(separator: ", ")
        group = serverGroup ?? name.releaseGroup
        size = DetailText.bytes(file.size)
        length = Self.minutes(probe?.runtimeSeconds)
        belowTier = FileNameFacts.isBelow(resolution: DetailText.resolution(file.quality) ?? name.resolution, tier: tier)
        deadLink = file.linkUnresolved == true
        analysing = file.analysis == "pending"
    }

    /// The row's second line: `WEBRip 1080p · h265 · AAC 2.0 · TiKos`,
    /// without the quality (the row tints it on its own).
    var rest: String {
        [video, audio, group].compactMap { $0 }.joined(separator: " · ")
    }

    /// The sheet's audio cell: `AAC 2.0 · English`.
    var audioWithLanguages: String? {
        let parts = [audio, languages].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// `130 MB · 11 min`.
    var sizeAndLength: String {
        [size, length].compactMap { $0 }.joined(separator: " · ")
    }

    private static func minutes(_ seconds: Double?) -> String? {
        guard let seconds, seconds.isFinite, seconds > 0 else { return nil }
        let m = Int((seconds / 60).rounded())
        if m < 60 { return "\(max(m, 1)) min" }
        return "\(m / 60) h \(m % 60) min"
    }
}
