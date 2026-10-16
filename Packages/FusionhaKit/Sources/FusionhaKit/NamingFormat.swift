import Foundation

// Settings › Naming, the pure half (web `MediaManagementPanel.tsx` NamingPanel):
// the per-kind format fields, the token palette, the preview samples and the
// client-side mirror of `services/naming.py` that renders one path component
// as colour-coded segments. `GET/PUT /api/v1/naming` is read and written as a
// plain JSON document by the app (`SettingsStore` with that path).

public enum NamingKind: String, CaseIterable, Sendable, Identifiable {
    case series, movie, anime
    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .series: return "Series"
        case .movie: return "Movie"
        case .anime: return "Anime"
        }
    }
}

/// One `NamingConfig` format field a kind shows.
public struct NamingField: Sendable, Hashable, Identifiable {
    public let key: String
    public let label: String
    public let placeholder: String?
    public var id: String { key }
}

/// What colour a rendered token takes in the preview (web `.tk*`).
public enum NamingTokenKind: Sendable, Hashable {
    case title, quality, customFormat, episode
}

/// One run of preview text: a literal (`kind == nil`) or a substituted token.
public struct NamingSegment: Sendable, Hashable {
    public var text: String
    public var kind: NamingTokenKind?

    public init(text: String, kind: NamingTokenKind? = nil) {
        self.text = text
        self.kind = kind
    }
}

public enum NamingFormat {
    public static let animeKey = "standard_anime_episode_format"

    public static func fields(_ kind: NamingKind) -> [NamingField] {
        switch kind {
        case .series:
            return [
                NamingField(key: "series_folder_format", label: "Series folder format", placeholder: nil),
                NamingField(key: "season_folder_format", label: "Season folder format", placeholder: nil),
                NamingField(key: "standard_episode_format", label: "Standard episode format", placeholder: nil),
            ]
        case .movie:
            return [
                NamingField(key: "movie_folder_format", label: "Movie folder format", placeholder: nil),
                NamingField(key: "standard_movie_format", label: "Movie file format", placeholder: nil),
            ]
        case .anime:
            return [
                NamingField(key: "series_folder_format", label: "Series folder format", placeholder: nil),
                NamingField(key: "season_folder_format", label: "Season folder format", placeholder: nil),
                NamingField(key: animeKey, label: "Anime episode format",
                            placeholder: "Empty → use the standard episode format"),
            ]
        }
    }

    /// Rendered by every kind (quality, formats, MediaInfo, group).
    static let commonTokens = [
        "{Release Year}", "{Quality Full}", "{Custom Formats}", "{MediaInfo Simple}",
        "{[MediaInfo VideoDynamicRangeType]}", "{-Release Group}",
    ]

    /// The palette for a kind: only tokens `naming.py` renders. The Plex
    /// `{edition-…}` group is movies only (a series edition goes on the show folder).
    public static func tokens(_ kind: NamingKind) -> [String] {
        switch kind {
        case .series:
            return ["{Series Title}", "{Series TitleYear}", "S{season:00}E{episode:00}", "Season {season:00}",
                    "{Episode Title}", "{Episode CleanTitle}", "{Air-Date}"] + commonTokens
        case .movie:
            return ["{Movie Title}", "{Movie TitleYear}", "{edition-{Edition Tags}}"] + commonTokens
        case .anime:
            return ["{Series Title}", "{Series TitleYear}", "S{season:00}E{episode:00}", "Season {season:00}",
                    "{absolute:000}", "{Episode Title}", "{Episode CleanTitle}", "{Air-Date}"] + commonTokens
        }
    }

    /// The preview's sample values per kind (web `SAMPLES`). An empty value
    /// previews the empty-token collapse.
    public static func sample(_ kind: NamingKind) -> [String: String] {
        switch kind {
        case .series:
            return [
                "Series Title": "FROM", "Series TitleYear": "FROM (2022)", "Series CleanTitle": "FROM",
                "Release Year": "2022", "season": "4", "episode": "1", "absolute": "45",
                "Episode Title": "The Arrival", "Episode CleanTitle": "The Arrival", "Air-Date": "2026-02-15",
                "Quality Full": "WEBDL-1080p", "Custom Formats": "AMZN", "MediaInfo VideoCodec": "h264",
                "MediaInfo AudioCodec": "EAC3", "MediaInfo AudioChannels": "5.1",
                "MediaInfo VideoDynamicRangeType": "", "MediaInfo Simple": "h264 EAC3",
                "Release Group": "FLUX", "Edition Tags": "Black & White",
            ]
        case .movie:
            return [
                "Movie Title": "Dune Part Two", "Movie TitleYear": "Dune Part Two (2024)",
                "Movie CleanTitle": "Dune Part Two", "Release Year": "2024", "Quality Full": "Bluray-2160p Remux",
                "Custom Formats": "DV HDR10+ TrueHD ATMOS", "MediaInfo VideoCodec": "h265",
                "MediaInfo AudioCodec": "TrueHD", "MediaInfo AudioChannels": "7.1",
                "MediaInfo VideoDynamicRangeType": "DV HDR10", "MediaInfo Simple": "h265 TrueHD",
                "Release Group": "FraMeSToR", "Edition Tags": "Director's Cut",
            ]
        case .anime:
            return [
                "Series Title": "Frieren", "Series TitleYear": "Frieren (2023)", "Series CleanTitle": "Frieren",
                "Release Year": "2023", "season": "1", "episode": "28", "absolute": "28",
                "Episode Title": "Aura the Guillotine", "Episode CleanTitle": "Aura the Guillotine",
                "Air-Date": "2026-02-15", "Quality Full": "Bluray-1080p", "Custom Formats": "Dual Audio",
                "MediaInfo VideoCodec": "h265", "MediaInfo AudioCodec": "FLAC", "MediaInfo AudioChannels": "2.0",
                "MediaInfo VideoDynamicRangeType": "", "MediaInfo Simple": "h265 FLAC",
                "Release Group": "SubsPlease", "Edition Tags": "Uncut",
            ]
        }
    }

    /// The sample the preview uses: series and anime blank the edition (it goes
    /// on the show folder only, never inside a format).
    public static func previewSample(_ kind: NamingKind) -> [String: String] {
        var s = sample(kind)
        if kind != .movie { s["Edition Tags"] = "" }
        return s
    }

    /// The preview's folder components and file format for a kind. An empty
    /// anime format falls back to the standard episode format.
    public static func previewFormats(_ kind: NamingKind, value: (String) -> String) -> (folders: [String], file: String) {
        switch kind {
        case .movie:
            return ([value("movie_folder_format")], value("standard_movie_format"))
        case .series:
            return ([value("series_folder_format"), value("season_folder_format")], value("standard_episode_format"))
        case .anime:
            let anime = value(animeKey)
            return ([value("series_folder_format"), value("season_folder_format")],
                    anime.isEmpty ? value("standard_episode_format") : anime)
        }
    }

    static func tokenKind(_ name: String) -> NamingTokenKind {
        if name.contains("Custom Formats") { return .customFormat }
        if name.contains("Quality") { return .quality }
        if name.contains("Title") || name.contains("Movie") || name.contains("Edition") { return .title }
        return .episode
    }

    /// `naming.py`'s `_ILLEGAL_REPLACEMENTS`.
    static let illegal: [(String, String)] = [
        ("<", ""), (">", ""), (":", " -"), ("\"", ""), ("/", ""), ("\\", ""), ("|", ""), ("?", ""), ("*", ""),
    ]

    // `{<prefix><Name>[:0N]<suffix>}` (naming.py `_TOKEN_RE`).
    static var tokenRegex: NSRegularExpression { try! NSRegularExpression(
        pattern: #"\{([- ._\[(]*)([A-Za-z0-9]+(?:[- ._][A-Za-z0-9]+)*)(?::(\d+))?([- ._)\]]*)\}"#) }
    // A Plex group wrapping one inner token (naming.py `_NESTED_GROUP_RE`).
    static var nestedRegex: NSRegularExpression { try! NSRegularExpression(
        pattern: #"\{[^\{\}]*\{([A-Za-z][A-Za-z0-9 ]*)\}[^\{\}]*\}"#) }
    static var spaces: NSRegularExpression { try! NSRegularExpression(pattern: #"\s{2,}"#) }
    static var intLike: NSRegularExpression { try! NSRegularExpression(pattern: #"^\s*[+-]?\d+\s*$"#) }
}
