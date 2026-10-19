import Foundation
import FusionhaKit

/// Monitor toggles for seasons, versions and episodes, flipped optimistically
/// while the PATCH is in flight.
extension DetailStore {
    func setSeasonMonitored(_ number: Int, _ on: Bool) async {
        guard let client else { return }
        let name = number == 0 ? "Specials" : "Season \(number)"
        seasonMonitorOverride[number] = on
        do {
            try await client.setSeasonMonitored(itemId: itemId, season: number, monitored: on)
            show(on ? "Monitoring \(name)" : "Stopped monitoring \(name)", variant: .success)
            await reload()
        } catch {
            seasonMonitorOverride[number] = nil
            show("Couldn't update \(name)", variant: .error)
        }
    }

    func setEditionMonitored(_ edition: DetailEdition, _ on: Bool) async {
        guard let client else { return }
        editionMonitorOverride[edition.id] = on
        do {
            try await client.updateEdition(itemId: itemId, editionId: edition.id, EditionUpdate(monitored: on))
            await reload()
        } catch {
            editionMonitorOverride[edition.id] = nil
            show("Couldn't update \(edition.label)", variant: .error)
        }
    }

    /// Per-episode monitor toggle (`PATCH /api/v1/library/{id}/episodes/{eid}`).
    func setEpisodeMonitored(_ episode: Episode, seasonNumber: Int, _ on: Bool) async {
        guard let client else { return }
        let code = EpisodeCode.episode(season: seasonNumber, episode: episode.episodeNumber)
        episodeMonitorOverride[episode.id] = on
        do {
            try await client.setEpisodeMonitored(itemId: itemId, episodeId: episode.id, monitored: on)
            await reload()
        } catch {
            episodeMonitorOverride[episode.id] = nil
            show("Couldn't update \(code)", variant: .error)
        }
    }
}
