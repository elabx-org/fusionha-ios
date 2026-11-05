import SwiftUI
import FusionhaKit

/// The Wanted scope's data (v1 `WantedView`'s loading and actions, kept as
/// they are): the state-independent totals, the 4K count, the paged feed of
/// the chosen tab, the activity settings, Search all and the 4K observer.
@MainActor
@Observable
final class V2WantedModel {
    var tab: WantedTab = .missing
    var searchInput = ""
    private(set) var search = ""
    private(set) var totals: WantedPage?
    private(set) var totalsFailed = false
    /// nil until the 4K feed's count arrives (the picker shows no number, not 0).
    private(set) var fourkCount: Int?
    private(set) var settings: ActivitySettings?
    private(set) var searchingAll = false
    let feed = ActFeed<WantedItem> { _, _ in ([], 0) }
    let fourkFeed = ActFeed<FourKAvailableItem> { _, _ in ([], 0) }

    func count(_ t: WantedTab) -> Int {
        switch t {
        case .missing: return totals?.missingTitles ?? 0
        case .cutoff: return totals?.cutoffUnmetTitles ?? 0
        case .upcoming: return totals?.upcomingTitles ?? 0
        case .fourk: return fourkCount ?? 0
        }
    }

    var interval: Int { settings?.seasonSearchIntervalSeconds ?? 5 }

    /// The debounced title search (300 ms, as v1).
    func debounce() async {
        if searchInput.isEmpty { search = ""; return }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        search = searchInput.trimmingCharacters(in: .whitespaces)
    }

    func loadSettings(_ client: APIClient?) async {
        settings = try? await client?.activitySettings()
    }

    func loadTotals(_ client: APIClient?) async {
        guard let client else { return }
        if totals == nil {
            totals = await client.cached { try await $0.wantedPage(state: nil, page: 1, pageSize: 1) }
            if let kept = await client.cached({ try await $0.fourKAvailable(page: 1, pageSize: 1) }) {
                fourkCount = kept.fourkAvailableCount ?? kept.total
            }
        }
        do {
            totals = try await client.wantedPage(state: nil, page: 1, pageSize: 1)
            totalsFailed = false
        } catch {
            totalsFailed = true
        }
        if let fourk = try? await client.fourKAvailable(page: 1, pageSize: 1) {
            fourkCount = fourk.fourkAvailableCount ?? fourk.total
        }
    }

    func loadFeed(_ client: APIClient?) async {
        let q = search
        if tab == .fourk {
            fourkFeed.source(client) { c, page, size in
                let r = try await c.fourKAvailable(page: page, pageSize: size, query: q)
                return (r.items, r.total)
            }
            await fourkFeed.reload(resetting: true)
        } else {
            let state = tab.state
            feed.source(client) { c, page, size in
                let r = try await c.wantedPage(state: state, page: page, pageSize: size, query: q)
                return (r.items, r.total)
            }
            await feed.reload(resetting: true)
        }
    }

    func reloadAll(_ client: APIClient?) async {
        await loadTotals(client)
        if tab == .fourk { await fourkFeed.refreshLoaded() } else { await feed.refreshLoaded() }
    }

    /// Search all (missing or upgrades) honouring the title search, then a
    /// toast and a reload, as v1.
    func searchAll(_ client: APIClient?, toaster: ActToaster) async {
        guard let client, let state = tab.state else { return }
        searchingAll = true
        defer { searchingAll = false }
        do {
            let n = try await WantedLogic.searchAll(client, state: state, query: search)
            toaster.show(n == 0 ? "Nothing to search." : "Searching \(ActFmt.plural(n, "title"))…",
                         tone: n == 0 ? .warning : .success)
        } catch {
            toaster.error(error)
        }
        await reloadAll(client)
    }

    func enableObserver(_ client: APIClient?, toaster: ActToaster) async {
        do {
            try await client?.updateActivitySettings(ActivitySettingsUpdate(uhdAvailableObserverEnabled: true))
            toaster.show("4K observing turned on.", tone: .success)
            settings = try? await client?.activitySettings()
            await fourkFeed.reload()
        } catch {
            toaster.error(error)
        }
    }

    /// The media empty state's playful one-liner, off in Plain voice.
    var emptyQuip: String? {
        guard settings?.voicePlayful ?? true else { return nil }
        return VoiceQuip.mediaSuffix(kind: .movie, title: tab.rawValue, outcome: .noRelease)
    }
}

extension WantedTab {
    /// The segmented picker's short label (mock `wTabs`).
    var shortLabel: String {
        switch self {
        case .missing: return "Missing"
        case .cutoff: return "Cutoff"
        case .upcoming: return "Upcoming"
        case .fourk: return "4K"
        }
    }
}

/// A wanted version as a T5 ticket and a few words (mock `K.ed`): a file
/// below its cutoff is still on disk; missing and upcoming are outlines.
enum V2WantedEditionCopy {
    static func badge(_ edition: WantedEdition) -> EditionBadgeState {
        switch edition.state {
        case "missing", "upcoming": return .missing
        default: return .onDisk
        }
    }

    static func words(_ edition: WantedEdition) -> String {
        switch edition.state {
        case "missing":
            if let n = edition.missingEpisodeCount, n > 0 { return "\(n) missing" }
            return "missing"
        case "cutoff_unmet": return "below cutoff"
        case "upcoming": return "upcoming"
        default: return "on disk"
        }
    }
}
