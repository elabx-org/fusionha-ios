import Foundation
import FusionhaKit

/// What one episode file is, in words: the server's facts (quality code,
/// probe fields `video_codec` / `audio_codec` / `audio_channels`, release
/// group) first, the filename's where the server has none.
struct EpisodeFileFacts {
    let quality: String?
    let video: String?
    let audio: String?
    let languages: String?
    let group: String?
    let size: String
    let length: String?
    /// The file's resolution (`720p`), from the server's quality or the name.
    let resolution: String?
    /// Below its version's tier (a 720p file in the 1080p version).
    let belowTier: Bool
    let deadLink: Bool
    let analysing: Bool

    init(file: MovieFile, tier: QualityTier) {
        let probe = file.mediaInfo?.probe
        let serverQuality = FileNameFacts.qualityText(file.quality)
        // The server's probe facts (0.4.236), else the probe read here.
        let serverVideo = file.probedVideo ?? DetailMediaFacts.codec(probe)
        let serverAudio = file.probedAudio ?? DetailMediaFacts.audio(probe)
        let serverGroup = file.releaseGroup.flatMap { $0.isEmpty ? nil : $0 }
        // Parse the name only when a fact is missing (never for probed files).
        let needsName = serverQuality == nil || serverVideo == nil || serverAudio == nil || serverGroup == nil
        let name = needsName ? FileNameFacts.parse(file.relativePath ?? file.sceneName ?? "") : FileNameFacts()

        quality = serverQuality ?? name.quality
        let range = DetailMediaFacts.range(probe).flatMap { $0 == "SDR" ? nil : $0 }
        let media = FileNameFacts.media(for: file, probeVideo: serverVideo, probeAudio: serverAudio, name: name)
        let codec = media.video
        let videoParts = [codec, range].compactMap { $0 }
        video = videoParts.isEmpty ? nil : videoParts.joined(separator: " ")
        audio = media.audio
        let named = (file.languages ?? []).filter { !$0.isEmpty }
        languages = named.isEmpty ? DetailMediaFacts.languages(probe) : named.joined(separator: ", ")
        group = serverGroup ?? name.releaseGroup
        size = DetailText.bytes(file.size)
        length = Self.minutes(probe?.runtimeSeconds)
        resolution = DetailText.resolution(file.quality) ?? name.resolution
        belowTier = FileNameFacts.isBelow(resolution: resolution, tier: tier)
        deadLink = file.linkUnresolved == true
        analysing = file.analysis == "pending"
    }

    /// The row's second line: `WEBRip 1080p · h265 · AAC 2.0 · TiKos`,
    /// without the quality (the row tints it on its own).
    var rest: String {
        [video, audio, group].compactMap { $0 }.joined(separator: " · ")
    }

    /// `720p, below this version's 1080p`, when the file is under its tier.
    func belowTierNote(_ tier: QualityTier) -> String? {
        guard belowTier, let resolution else { return nil }
        return "\(resolution), below this version's \(tier.shortLabel)"
    }

    /// `Imported · symlink`, or the dead link (shown in the stuck colour).
    func onDisk(_ file: MovieFile) -> String {
        if deadLink { return "Dead link · target gone from disk" }
        guard let mode = file.mediaInfo?.finalMode, !mode.isEmpty else { return "Imported" }
        return "Imported · \(mode.lowercased())"
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
