import SwiftUI
import FusionhaKit

// The configure step's derived values (kind, anime, profiles, folder, provider, ids).
extension AddFlow {
    var kind: MediaKind { pick.kind }
    var isSeries: Bool { kind == .series }
    var title: String { pick.title }
    var year: Int? { pick.year }
    var isTvdb: Bool { if case .tvdb = pick { return true } else { return false } }

    /// Anime when TMDB flagged it OR Series type = Anime.
    var effectiveAnime: Bool {
        switch pick {
        case .tmdb(let r): return r.isAnime || (r.kind == .series && seriesType == "anime")
        case .tvdb: return seriesType == "anime"
        }
    }

    /// TMDB itself flags the pick as anime (the "Detected: anime" tag).
    var detectedAnime: Bool { pick.tmdbAnime }

    var ready: Bool { versions != nil }

    /// `profilesForItem`: kindless profiles plus the title's kind (and anime).
    static func profilesFor(_ profiles: [QualityProfileSummary], kind: MediaKind, anime: Bool) -> [QualityProfileSummary] {
        let kinds: Set<String> = anime ? ["anime", kind.rawValue] : [kind.rawValue]
        return profiles.filter { $0.mediaKind == nil || kinds.contains($0.mediaKind ?? "") }
    }

    var profileOptions: [QualityProfileSummary] {
        Self.profilesFor(profiles ?? [], kind: kind, anime: effectiveAnime)
    }

    var onTiers: [QualityTier] { versions.map { v in Self.tiers.filter { v[$0]?.on == true } } ?? [] }

    /// The preview's seasons, in season order (series only).
    var seasons: [SeasonCounts]? {
        guard isSeries, let list = preview?.seasons else { return nil }
        return list.sorted { $0.seasonNumber < $1.seasonNumber }.map {
            SeasonCounts(seasonNumber: $0.seasonNumber, episodeCount: $0.episodeCount,
                         airedCount: $0.airedCount, recentCount: $0.recentCount)
        }
    }

    var hasCustomSeasons: Bool { !seasonFrom.isEmpty }

    var derivedFolder: String { TitleYear.titleWithYear(title, year) }
    var trimmedFolder: String { folderName.trimmingCharacters(in: .whitespaces) }
    var folderEdited: Bool { !trimmedFolder.isEmpty && trimmedFolder != derivedFolder }
    /// The folder every version lands in (the field, else the default).
    var shownFolder: String { trimmedFolder.isEmpty ? derivedFolder : trimmedFolder }

    /// The global default "Automatic" resolves to (Settings › Metadata).
    var defaultProvider: String { settings?.metadataProvider ?? "tmdb" }
    var chosenProvider: String { provider != "auto" ? provider : defaultProvider }
    /// A TVDB-only pick can only be built by TVDB or Hybrid.
    var effectiveProvider: String {
        isTvdb ? Self.tvdbPickProvider(chosenProvider) : chosenProvider
    }

    static func tvdbPickProvider(_ choice: String) -> String { choice == "hybrid" ? "hybrid" : "tvdb" }

    /// The provider choice is offered for TMDB-picked series only.
    var showProviderChoice: Bool { !isTvdb && isSeries }

    /// Every id known for the pick ("Identified as"); the preview fills TVDB/IMDb.
    var ids: (tmdb: Int?, tvdb: Int?, imdb: String?) {
        switch pick {
        case .tmdb(let r):
            return (r.tmdbId, preview?.tvdbId, preview?.imdbId)
        case .tvdb(let r):
            return (r.tmdbId ?? preview?.tmdbId, preview?.tvdbId ?? r.tvdbId, preview?.imdbId ?? r.imdbId)
        }
    }
}
