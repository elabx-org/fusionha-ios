import SwiftUI
import FusionhaKit

extension AddFlow {
    // MARK: Payload

    var chosenVersions: [AddVersionBody] {
        guard let versions else { return [] }
        let folder = folderEdited ? trimmedFolder : nil
        return onTiers.compactMap { tier in
            guard let state = versions[tier] else { return nil }
            let edition = editions[tier]
            return AddVersionBody(tier: tier, edition: AddVocab.isStandardEdition(edition) ? nil : edition,
                                  rootFolderId: state.rootId, qualityProfileId: state.profileId,
                                  monitor: isSeries && state.monitor != monitor ? state.monitor : nil,
                                  folderName: folder)
        }
    }

    var canSubmit: Bool { !chosenVersions.isEmpty && !isAdding }

    /// The `POST /api/v1/library` body, or nil when nothing can be added yet.
    func payload() -> AddTitleBody? {
        let chosen = chosenVersions
        if chosen.isEmpty { return nil }
        // Per-season starts need one shared level, and never ride an anime add.
        let shared = chosen.allSatisfy { $0.monitor == nil }
        let custom = isSeries && shared && !effectiveAnime ? SeasonSlider.payload(seasonFrom) : nil
        switch pick {
        case .tmdb(let r):
            return AddTitleBody(title: r.title, kind: r.kind, year: r.year, tmdbId: r.tmdbId, tvdbId: nil,
                                isAnime: effectiveAnime, versions: chosen, searchNow: searchNow,
                                monitor: isSeries ? monitor : "all", minimumAvailability: isSeries ? nil : minAvail,
                                seriesType: isSeries ? seriesType : nil,
                                metadataProvider: isSeries && provider != "auto" ? provider : nil,
                                seasonMonitorFrom: custom)
        case .tvdb(let r):
            return AddTitleBody(title: r.title, kind: .series, year: r.year, tmdbId: nil, tvdbId: r.tvdbId,
                                isAnime: effectiveAnime, versions: chosen, searchNow: searchNow, monitor: monitor,
                                minimumAvailability: nil, seriesType: seriesType,
                                metadataProvider: Self.tvdbPickProvider(chosenProvider), seasonMonitorFrom: custom)
        }
    }
}
