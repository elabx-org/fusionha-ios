import Foundation
import FusionhaKit

// The scoped automatic and gradual searches (SearchActionButton, SeasonGradualProgress).
extension DetailStore {
    // MARK: Searches

    /// The scoped automatic search. Returns the decisions (nil on failure) and
    /// drives the flash strip and the toast like the web's SearchActionButton.
    @discardableResult
    func search(label: String, editionId: Int? = nil, season: Int? = nil, episodeId: Int? = nil,
                missingOnly: Bool = false) async -> [SearchDecision]? {
        guard let client else { return nil }
        flash = SearchFlash(phase: .searching, scope: label)
        do {
            let decisions = try await client.search(itemId: itemId, editionId: editionId, season: season,
                                                    episodeId: episodeId, missingOnly: missingOnly)
            let grabbed = decisions.filter(\.grabbed)
            flash = SearchFlash(phase: .done, scope: label, grabbed: grabbed.count, score: grabbed.compactMap(\.score).max())
            if grabbed.isEmpty {
                // A completed no-grab: amber, never red, with the pause reason when auto was paused.
                show(SearchPauseNote.nothingGrabbed(label, note: pauseNote(editionId: editionId, season: season, episodeId: episodeId)),
                     variant: .warning, actionLabel: "View trail") { [weak self] in self?.viewTrail() }
            } else {
                let versions = Set(grabbed.compactMap(\.editionId)).count
                let n = max(versions, 1)
                show("Searching \(label) — grabbing \(n) version\(n == 1 ? "" : "s")", variant: .success,
                     actionLabel: "View trail") { [weak self] in self?.viewTrail() }
            }
            scheduleFlashClear()
            await reload()
            await loadRuns()
            return decisions
        } catch {
            flash = nil
            show("Couldn't search \(label)", variant: .error)
            return nil
        }
    }

    /// "View trail": the Searches tab (closing the search or episode sheet first).
    func viewTrail() {
        interactive = nil
        episodeSheet = nil
        tab = .searches
    }

    /// `pauseToastNote` for this search's scope: an episode's failed-download
    /// cooldown, or a season's empty-search backoff.
    private func pauseNote(editionId: Int?, season: Int?, episodeId: Int?) -> String? {
        let ids = Set(editionId.map { [$0] } ?? scopedEditions.map(\.id))
        let clock: (Date) -> String = { $0.formatted(date: .omitted, time: .shortened) }
        if let episodeId {
            return SearchPauseNote.note(cooldown: SearchPauseNote.cooldown(pauses, episodeId: episodeId, versionIds: ids),
                                        backoff: nil, clock: clock)
        }
        if let season {
            return SearchPauseNote.note(cooldown: nil, backoff: SearchPauseNote.backoff(pauses, season: season, versionIds: ids),
                                        clock: clock)
        }
        return nil
    }

    func scheduleFlashClear() {
        let current = flash?.id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            if self?.flash?.id == current { self?.flash = nil }
        }
    }

    /// One-at-a-time search of the whole title (`season == nil`) or one season.
    func gradualSearch(label: String, season: Int? = nil, editionId: Int? = nil, missingOnly: Bool) async {
        guard let client else { return }
        do {
            let start = try await client.gradualSearch(itemId: itemId, season: season, editionId: editionId, missingOnly: missingOnly)
            guard let runId = start.runId, (start.total ?? 0) > 0 else {
                show(missingOnly ? "\(label): no missing episodes — nothing to search"
                                 : "\(label): all episodes meet the cutoff — nothing to upgrade", variant: .warning)
                return
            }
            gradual = GradualJob(runId: runId, season: season, total: start.total ?? 0, label: label)
            await pollGradual(runId: runId)
        } catch {
            show("Couldn't search \(label)", variant: .error)
        }
    }

    func pollGradual(runId: Int) async {
        guard let client else { return }
        while let job = gradual, job.runId == runId {
            try? await Task.sleep(for: .seconds(1.5))
            guard let run = try? await client.commandRun(id: runId) else { continue }
            gradual?.current = run.progressCurrent ?? gradual?.current ?? 0
            if let total = run.progressTotal { gradual?.total = total }
            if !run.isRunning {
                gradual = nil
                let grabbed = (run.grabbed ?? 0) + (run.upgraded ?? 0)
                show(grabbed > 0 ? "Searched \(job.label) — grabbed \(grabbed)" : "Searched \(job.label) — nothing grabbed",
                     variant: grabbed > 0 ? .success : .warning)
                await reload()
                await loadRuns()
            }
        }
    }

    func stopGradual() async {
        guard let client, let job = gradual else { return }
        gradual?.stopping = true
        try? await client.cancelGradualSearch(itemId: itemId, season: job.season)
    }
}
