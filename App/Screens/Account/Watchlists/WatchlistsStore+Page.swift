import SwiftUI
import FusionhaKit

/// The Watchlists & lists page's reads and writes (web `use-sync.ts`,
/// `manage-actions.ts`, `LetterboxdOptions`, `PlexOptions`, fusionha 0.4.226).
/// Every write re-reads the summary and the reads behind it.
extension WatchlistsStore {
    /// The rows in summary order, or nil until the summary has answered.
    var views: [AutoSourceView]? {
        summary.map {
            AutoSourceViews.build($0, letterboxd: letterboxd, sources: sources, plex: plex,
                                  lbUnread: !loaded && letterboxd == nil, plexUnread: !loaded && plex == nil)
        }
    }

    func view(_ id: String?) -> AutoSourceView? {
        guard let id else { return nil }
        return views?.first { $0.sourceId == id }
    }

    func loadSummary(_ client: APIClient) async {
        do {
            summary = try await client.automaticRequestsSummary()
            summaryFailed = false
        } catch {
            if summary == nil { summaryFailed = true }
        }
    }

    /// Admin only: the remembered matches.
    func loadMatches(_ client: APIClient?) async {
        guard let client, let rows = try? await client.listMatches() else { return }
        matches = rows
    }

    // MARK: Sync

    /// Sync now for everything: 202, then the summary every 2 s until the pass
    /// it started has run and ended, then the shipped "Checked…" toast.
    func syncAll(_ model: AppModel) async {
        guard let client = model.client, !allSyncing else { return }
        allSyncing = true
        defer { allSyncing = false }
        let before = summary?.requestedLast7d ?? 0
        do {
            allRetryAt = try await client.syncAutomaticRequests().syncAvailableAt
        } catch {
            if let at = (error as? APIError)?.retryAt { allRetryAt = at }
            model.toast(AutomaticRequestsCopy.syncError(error), variant: .error)
            return
        }
        var seen = false
        for round in 0..<30 {
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            await refreshProgress(client)
            if summary?.syncing != nil { seen = true } else if seen || round >= 4 { break }
        }
        guard let summary else { return }
        model.toast(AutomaticRequestsCopy.syncDone(sources: summary.sources.count,
                                                   added: max(0, summary.requestedLast7d - before)))
    }

    /// Whether this source has a Sync of its own (a Letterboxd source needs its row id).
    func canSync(_ view: AutoSourceView) -> Bool { view.isPlex || view.rowId != nil }

    /// Sync this source: Plex through its watchlist sync, Letterboxd by row id.
    func syncOne(_ view: AutoSourceView, _ model: AppModel) async {
        guard let client = model.client, syncingSource == nil else { return }
        syncingSource = view.sourceId
        defer { syncingSource = nil }
        do {
            if view.isPlex {
                plex = try await client.syncPlexWatchlist()
            } else if let id = view.rowId {
                _ = try await client.syncRequestSource(id: id)
            }
        } catch {
            model.toast(AutomaticRequestsCopy.syncError(error), variant: .error)
            return
        }
        await refreshProgress(client)
    }

    // MARK: Writes

    /// Runs one write, then re-reads the page; toasts `success` or the failure.
    @discardableResult
    func act(_ model: AppModel, success: String? = nil,
             failure: (Error) -> String = { _ in SourceDetailCopy.failed },
             _ call: (APIClient) async throws -> Void) async -> Bool {
        guard let client = model.client else { return false }
        acting = true
        defer { acting = false }
        do {
            try await call(client)
        } catch {
            model.toast(failure(error), variant: .error)
            return false
        }
        await refreshProgress(client)
        if let success { model.toast(success) }
        return true
    }

    private var username: String? { letterboxd?.username }

    private func lbUser(_ view: AutoSourceView) throws -> String {
        guard let user = username ?? view.lb?.owner else { throw APIError.http(status: 400, body: "") }
        return user
    }

    /// The source's own on / off switch (Options), per kind.
    @discardableResult
    func setEnabled(_ view: AutoSourceView, _ on: Bool, _ model: AppModel) async -> Bool {
        await act(model) { client in
            switch view.kind {
            case .diary: _ = try await client.updateLetterboxd(username: lbUser(view), diaryEnabled: on)
            case .ownWatchlist: _ = try await client.followLetterboxdWatchlist(enabled: on)
            case .list, .watchlist:
                guard let id = view.rowId else { return }
                _ = try await client.updateRequestSource(id: id, enabled: on)
            case .plexWatchlist: plex = try await client.updatePlexWatchlist(enabled: on)
            case .plexList:
                guard let list = view.plexList else { return }
                plex = try await client.setPlexList(listId: list.listId, enabled: on)
            }
        }
    }

    /// "Also request UHD·4K" on the diary, the own watchlist or the Plex watchlist.
    @discardableResult
    func setUhd(_ view: AutoSourceView, _ on: Bool, _ model: AppModel) async -> Bool {
        await act(model) { client in
            switch view.kind {
            case .diary: _ = try await client.updateLetterboxd(username: lbUser(view), alsoUhd: on)
            case .ownWatchlist: _ = try await client.followLetterboxdWatchlist(alsoUhd: on)
            case .plexWatchlist: plex = try await client.updatePlexWatchlist(alsoUhd: on)
            default: return
            }
        }
    }

    @discardableResult
    func setRewatch(_ view: AutoSourceView, _ on: Bool, _ model: AppModel) async -> Bool {
        await act(model) { client in
            _ = try await client.updateLetterboxd(username: lbUser(view), requestRewatches: on)
        }
    }

    /// "What was on it when you started": `new` or `existing`.
    @discardableResult
    func setBaseline(_ view: AutoSourceView, _ value: String, _ model: AppModel) async -> Bool {
        await act(model) { try await $0.setRequestSourceBaseline(view.sourceId, baseline: value) }
    }

    /// Pause, Resume (own pause), or turn an off source back on with its switch.
    @discardableResult
    func togglePause(_ view: AutoSourceView, enabled: Bool, _ model: AppModel) async -> Bool {
        let running = enabled && !view.source.paused
        if !running && !view.source.paused {
            return await setEnabled(view, true, model)
        }
        return await act(model, failure: { SourceDetailCopy.pauseError($0, resuming: !running) }) {
            try await $0.pauseRequestSource(view.sourceId, paused: running)
        }
    }

    /// Whether the source can be removed here, and whether that disconnects Letterboxd.
    static func removal(_ view: AutoSourceView) -> (allowed: Bool, disconnects: Bool) {
        switch view.kind {
        case .diary, .ownWatchlist: return (true, true)
        case .list, .watchlist: return (view.rowId != nil, false)
        case .plexList: return (view.plexList?.deleted == true, false)
        case .plexWatchlist: return (false, false)
        }
    }

    func remove(_ view: AutoSourceView, _ model: AppModel) async -> Bool {
        await act(model, success: SourceDetailCopy.removed) { client in
            switch view.kind {
            case .diary, .ownWatchlist: try await client.disconnectLetterboxd()
            case .list, .watchlist:
                guard let id = view.rowId else { return }
                try await client.deleteRequestSource(id: id)
            case .plexList:
                guard let list = view.plexList else { return }
                try await client.removePlexList(listId: list.listId)
            case .plexWatchlist: return
            }
        }
    }

    /// Admin: forget one remembered match.
    func forget(_ match: ListMatch, _ model: AppModel) async {
        guard let client = model.client else { return }
        do {
            try await client.forgetListMatch(provider: match.provider, externalKey: match.externalKey)
            matches.removeAll { $0.id == match.id }
        } catch {
            model.toast(SourceDetailCopy.failed, variant: .error)
        }
    }
}
