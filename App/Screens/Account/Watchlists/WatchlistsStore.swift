import SwiftUI
import FusionhaKit

/// Account › Watchlists & lists: the Plex card, the Letterboxd card and the
/// linked sources, loaded together and replaced by each mutation's answer
/// (web `usePlexWatchlist`, `useLetterboxd`, `useRequestSources`).
@MainActor
@Observable
final class WatchlistsStore {
    var plex: PlexWatchlistRead?
    var letterboxd: LetterboxdRead?
    var sources: [LbSource] = []
    var loaded = false
    /// A Plex or Letterboxd write is in flight (switches disable meanwhile).
    var plexBusy = false
    var letterboxdBusy = false
    /// A 429's next-allowed moment, kept until the read model catches up.
    var plexRetryAt: String?
    var letterboxdRetryAt: String?
    var plexSyncing = false
    var letterboxdSyncing = false

    func load(_ client: APIClient?) async {
        guard let client else { return }
        async let plexRead = try? client.plexWatchlist()
        async let lbRead = try? client.letterboxd()
        plex = await plexRead
        letterboxd = await lbRead
        await loadSources(client)
        loaded = true
    }

    func loadSources(_ client: APIClient) async {
        guard let read = letterboxd, LetterboxdLogic.allowed(read) else {
            sources = []
            return
        }
        if let list = try? await client.requestSources() { sources = list }
    }

    // MARK: Sync progress (0.4.215)

    /// Any Plex or Letterboxd source mid-pass: the screen re-reads every 2 s.
    var anyRunning: Bool { SyncProgress.plexRunning(plex) || letterboxdRunning }

    var letterboxdRunning: Bool { SyncProgress.letterboxdRunning(letterboxd, sources: sources) }

    /// A quiet re-read of both cards and the linked sources while a source runs.
    func refreshProgress(_ client: APIClient?) async {
        guard let client else { return }
        async let plexRead = try? client.plexWatchlist()
        async let lbRead = try? client.letterboxd()
        if let next = await plexRead { plex = next }
        if let next = await lbRead { letterboxd = next }
        await loadSources(client)
    }

    // MARK: Plex

    /// Runs one Plex write and keeps its answer; toasts `success` or the error.
    @discardableResult
    func plexChange(_ model: AppModel, success: ((PlexWatchlistRead) -> String?)? = nil,
                    _ call: (APIClient) async throws -> PlexWatchlistRead) async -> Bool {
        guard let client = model.client else { return false }
        plexBusy = true
        defer { plexBusy = false }
        do {
            let next = try await call(client)
            plex = next
            if let text = success?(next) { model.toast(text) }
            return true
        } catch {
            model.toast(WatchlistErrorCopy.plexMessage(for: error), variant: .error)
            return false
        }
    }

    /// Sync now: 202, then the read model every 2 s for up to 90 s until
    /// `last_checked_at` moves past the request, then the "Checked…" toast.
    func syncPlex(_ model: AppModel) async {
        guard let client = model.client, let before = plex else { return }
        plexSyncing = true
        defer { plexSyncing = false }
        let started = Date().addingTimeInterval(-1)
        do {
            plex = try await client.syncPlexWatchlist()
        } catch {
            plexRetryAt = (error as? APIError)?.retryAt
            model.toast(WatchlistErrorCopy.plexMessage(for: error), variant: .error)
            return
        }
        let lists = before.lists.sources.filter { $0.enabled && !$0.deleted }.count
        for _ in 0..<45 {
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            guard let next = try? await client.plexWatchlist() else { continue }
            plex = next
            if let checked = ServerTime.parse(next.lastCheckedAt), checked >= started {
                let added = max(0, next.requestedTotal - before.requestedTotal)
                model.toast(PlexWatchlistCopy.syncDone(lists: lists, added: added))
                return
            }
        }
    }

    // MARK: Letterboxd

    /// Runs one Letterboxd write that answers the card, then refreshes the sources.
    @discardableResult
    func letterboxdChange(_ model: AppModel, success: ((LetterboxdRead) -> String?)? = nil,
                          _ call: (APIClient) async throws -> LetterboxdRead) async -> LetterboxdRead? {
        guard let client = model.client else { return nil }
        letterboxdBusy = true
        defer { letterboxdBusy = false }
        do {
            let next = try await call(client)
            letterboxd = next
            await loadSources(client)
            if let text = success?(next) { model.toast(text) }
            return next
        } catch {
            if let at = (error as? APIError)?.retryAt { letterboxdRetryAt = at }
            model.toast(WatchlistErrorCopy.letterboxdMessage(for: error), variant: .error)
            return nil
        }
    }

    /// A write on the linked sources (add, switch, remove, sync), then a reload.
    @discardableResult
    func sourceChange(_ model: AppModel, success: String?, _ call: (APIClient) async throws -> Void) async -> Bool {
        guard let client = model.client else { return false }
        letterboxdBusy = true
        defer { letterboxdBusy = false }
        do {
            try await call(client)
            letterboxd = (try? await client.letterboxd()) ?? letterboxd
            await loadSources(client)
            if let success { model.toast(success) }
            return true
        } catch {
            model.toast(WatchlistErrorCopy.letterboxdMessage(for: error), variant: .error)
            return false
        }
    }

    /// Sync now for every Letterboxd source (5 minutes per source): polls both
    /// reads every 2 s for up to 60 s, then toasts the films requested meanwhile.
    func syncLetterboxd(_ model: AppModel) async {
        guard let client = model.client else { return }
        letterboxdSyncing = true
        defer { letterboxdSyncing = false }
        let before = requestedTotal
        let checkedBefore = sources.compactMap { ServerTime.parse($0.lastCheckedAt) }.max()
        do {
            let result = try await client.syncLetterboxd()
            letterboxdRetryAt = result.syncAvailableAt
        } catch {
            letterboxdRetryAt = (error as? APIError)?.retryAt
            model.toast(WatchlistErrorCopy.letterboxdMessage(for: error), variant: .error)
            return
        }
        for _ in 0..<30 {
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            letterboxd = (try? await client.letterboxd()) ?? letterboxd
            await loadSources(client)
            let checked = sources.compactMap { ServerTime.parse($0.lastCheckedAt) }.max()
            if let checked, checked > (checkedBefore ?? .distantPast) { break }
        }
        model.toast(LetterboxdLogic.syncDone(max(0, requestedTotal - before)))
    }

    /// Films requested across every source (web `requestedTotal`).
    var requestedTotal: Int {
        let sum = sources.reduce(0) { $0 + $1.requestedCount }
        return sum > 0 ? sum : (letterboxd?.diary?.requestedCount ?? 0)
    }
}
