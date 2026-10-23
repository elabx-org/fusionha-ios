import SwiftUI
import FusionhaKit

/// Account › Watchlists & lists: the summary (order and states), the Plex and
/// Letterboxd reads and the linked sources, loaded together and replaced by
/// each mutation's answer (web `useAutomaticSummary`, `usePlexWatchlist`,
/// `useLetterboxd`, `useRequestSources`). The page's actions are in
/// `WatchlistsStore+Page.swift`.
@MainActor
@Observable
final class WatchlistsStore {
    var plex: PlexWatchlistRead?
    var letterboxd: LetterboxdRead?
    var sources: [LbSource] = []
    var loaded = false
    /// A Letterboxd profile write is in flight (its buttons disable meanwhile).
    var letterboxdBusy = false
    /// 0.4.226: the Account row and the page's sources, states and order.
    var summary: AutoSummary?
    var summaryFailed = false
    /// Sync all is in flight (ours), and its 429's next-allowed moment.
    var allSyncing = false
    var allRetryAt: String?
    /// One source's Sync now in flight, and a write on the page in flight.
    var syncingSource: String?
    var acting = false
    /// Admin only: the remembered matches.
    var matches: [ListMatch] = []

    func load(_ client: APIClient?) async {
        guard let client else { return }
        async let plexRead = try? client.plexWatchlist()
        async let lbRead = try? client.letterboxd()
        async let summaryRead: Void = loadSummary(client)
        plex = await plexRead
        letterboxd = await lbRead
        await loadSources(client)
        await summaryRead
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

    /// Any source mid-pass: the screen re-reads every 2 s.
    var anyRunning: Bool { SyncProgress.plexRunning(plex) || letterboxdRunning || summary?.syncing != nil }

    var letterboxdRunning: Bool { SyncProgress.letterboxdRunning(letterboxd, sources: sources) }

    /// A quiet re-read of everything the page shows.
    func refreshProgress(_ client: APIClient?) async {
        guard let client else { return }
        async let plexRead = try? client.plexWatchlist()
        async let lbRead = try? client.letterboxd()
        if let next = await plexRead { plex = next }
        if let next = await lbRead { letterboxd = next }
        await loadSources(client)
        await loadSummary(client)
    }

    // MARK: Letterboxd profile

    /// Runs one Letterboxd profile write that answers the read, then refreshes.
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
            await loadSummary(client)
            if let text = success?(next) { model.toast(text) }
            return next
        } catch {
            model.toast(WatchlistErrorCopy.letterboxdMessage(for: error), variant: .error)
            return nil
        }
    }

    /// A write that answers nothing (disconnect), then a reload.
    @discardableResult
    func sourceChange(_ model: AppModel, success: String?, _ call: (APIClient) async throws -> Void) async -> Bool {
        guard let client = model.client else { return false }
        letterboxdBusy = true
        defer { letterboxdBusy = false }
        do {
            try await call(client)
            letterboxd = (try? await client.letterboxd()) ?? letterboxd
            await loadSources(client)
            await loadSummary(client)
            if let success { model.toast(success) }
            return true
        } catch {
            model.toast(WatchlistErrorCopy.letterboxdMessage(for: error), variant: .error)
            return false
        }
    }
}
