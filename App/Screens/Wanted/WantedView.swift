import SwiftUI
import FusionhaKit

// The web's Wanted page (`routes/Wanted.tsx`, `Wanted.module.css`): the head with
// state-independent totals, the OverviewStrip, the Missing / Cutoff Unmet /
// Upcoming / 4K Available chips, search + "Search all", the lead, the per-title
// GroupCards (edition chips, context cue, search modes, missing episodes) and
// the 4K Available feed (see WantedFourK.swift).

struct WantedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var tab: WantedTab = WantedView.initialTab
    @State private var searchInput = ""
    @State private var search = ""
    @State private var totals: WantedPage?
    @State private var totalsFailed = false
    @State private var fourkCount = 0
    @State private var settings: ActivitySettings?
    @State private var searchingAll = false
    @State private var toaster = ActToaster()
    @State private var feed = ActFeed<WantedItem> { _, _ in ([], 0) }
    @State private var fourkFeed = ActFeed<FourKAvailableItem> { _, _ in ([], 0) }
    @State private var addEditionFor: FourKAvailableItem?

    private static var initialTab: WantedTab {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_WANTED_TAB"], let tab = WantedTab(rawValue: raw) {
            return tab
        }
        #endif
        return .missing
    }

    private var reduce: Bool { systemReduceMotion || settings?.animationsEnabled == false }

    private func count(_ t: WantedTab) -> Int {
        switch t {
        case .missing: return totals?.missingTitles ?? 0
        case .cutoff: return totals?.cutoffUnmetTitles ?? 0
        case .upcoming: return totals?.upcomingTitles ?? 0
        case .fourk: return fourkCount
        }
    }

    var body: some View {
        let _ = PerfCount.hit("WantedView.body")
        Screen(showsAdd: true) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    if totals == nil && !totalsFailed {
                        ActEmpty(message: "Loading wanted titles…").padding(.top, 14)
                    } else if totalsFailed && totals == nil {
                        ActEmpty(message: "The wanted list could not be loaded. Check the backend and try again.").padding(.top, 14)
                    } else {
                        overview.padding(.top, 14).padding(.bottom, 16)
                        filterBar
                        lead.padding(.top, 10).padding(.bottom, 14)
                        if tab == .fourk { fourkList } else { wantedList }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 20)
                .padding(.bottom, 90)
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable { await reloadAll() }
        }
        .overlay { ActToastOverlay(toaster: toaster).padding(.bottom, 70) }
        .environment(\.actReduceMotion, reduce)
        .environment(toaster)
        .task { await loadTotals() }
        .task {
            settings = try? await model.client?.activitySettings()
        }
        .task(id: searchInput) {
            if searchInput.isEmpty { search = ""; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            search = searchInput.trimmingCharacters(in: .whitespaces)
        }
        .task(id: "\(tab.rawValue)|\(search)") { await loadFeed() }
        .sheet(item: $addEditionFor) { item in
            WantedAddEditionSheet(item: item) {
                addEditionFor = nil
                toaster.show("Added a 4K version for \(item.title)", tone: .success)
                Task { await reloadAll() }
            } onCancel: { addEditionFor = nil }
        }
    }

    // MARK: Data

    private func loadTotals() async {
        guard let client = model.client else { return }
        do {
            let page = try await client.wantedPage(state: nil, page: 1, pageSize: 1)
            if reduce { totals = page } else { withAnimation(ActMotion.reveal()) { totals = page } }
            totalsFailed = false
        } catch {
            totalsFailed = true
        }
        if let fourk = try? await client.fourKAvailable(page: 1, pageSize: 1) {
            fourkCount = fourk.fourkAvailableCount ?? fourk.total
        }
    }

    private func loadFeed() async {
        let client = model.client
        let q = search
        if tab == .fourk {
            fourkFeed.fetch = { page, size in
                guard let client else { return ([], 0) }
                let r = try await client.fourKAvailable(page: page, pageSize: size, query: q)
                return (r.items, r.total)
            }
            await fourkFeed.reload(resetting: true)
        } else {
            let state = tab.state
            feed.fetch = { page, size in
                guard let client else { return ([], 0) }
                let r = try await client.wantedPage(state: state, page: page, pageSize: size, query: q)
                return (r.items, r.total)
            }
            await feed.reload(resetting: true)
        }
    }

    private func reloadAll() async {
        await loadTotals()
        if tab == .fourk { await fourkFeed.refreshLoaded() } else { await feed.refreshLoaded() }
    }

    // MARK: Head

    private var header: some View {
        let total = totals?.total ?? 0
        return ActFlow(spacing: 12, lineSpacing: 8) {
            Text("Wanted")
                .pageTitle()
            (Text(total == 1 ? "1 wanted title" : "\(total) wanted titles")
             + Text(total > 0 ? " · \(count(.missing)) missing, \(count(.cutoff)) below cutoff, \(count(.upcoming)) upcoming\(fourkCount > 0 ? ", \(fourkCount) seen in 4K" : "")" : "")
                .foregroundColor(Theme.dim))
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private var overview: some View {
        ActOverview(total: totals?.total ?? 0, label: "wanted titles", stats: [
            .init(label: "Missing", value: count(.missing), color: Theme.miss),
            .init(label: "Below cutoff", value: count(.cutoff), color: Theme.edition),
            .init(label: "Upcoming", value: count(.upcoming), color: Theme.unaired),
            .init(label: "4K available", value: fourkCount, color: QualityTier.uhd.color),
        ])
    }

    // MARK: Filter bar

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ActFlow(spacing: 8, lineSpacing: 8) {
                ForEach(WantedTab.allCases, id: \.self) { t in
                    ActChip(label: t.label, count: count(t), accent: t.accent, selected: tab == t) {
                        if reduce { tab = t } else { withAnimation(.snappy(duration: 0.25)) { tab = t } }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: tab)
            ActSearch(placeholder: "Search by title…", text: $searchInput)
            if tab == .missing || tab == .cutoff {
                Button {
                    Task { await searchAll() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold))
                        Text(searchingAll ? "Searching…" : (tab == .cutoff ? "Search all upgrades" : "Search all missing"))
                    }
                }
                .buttonStyle(ActButtonStyle(kind: .ghost))
                .disabled(count(tab) == 0 || searchingAll)
                .opacity(count(tab) == 0 ? 0.5 : 1)
            }
        }
        .padding(.bottom, 8)
    }

    /// The web's Search all: every state-matching title (500 cap, honouring the
    /// search box), then the per-item engine search on each unique title.
    private func searchAll() async {
        guard let client = model.client, let state = tab.state else { return }
        searchingAll = true
        defer { searchingAll = false }
        do {
            let page = try await client.wantedPage(state: state, page: 1, pageSize: 500, query: search)
            var seen = Set<Int>()
            let ids = page.items.map(\.id).filter { seen.insert($0).inserted }
            try await withThrowingTaskGroup(of: Void.self) { group in
                for id in ids { group.addTask { try await client.runSearch(itemId: id) } }
                try await group.waitForAll()
            }
        } catch {
            toaster.error(error)
        }
    }

    // MARK: Lead

    private var lead: some View {
        let dot = Text(Image(systemName: "circle.fill")).font(.system(size: 6)).foregroundColor(tab.accent).baselineOffset(1.5)
        let b: (String) -> Text = { Text($0).foregroundColor(Theme.txt).bold() }
        let text: Text
        switch tab {
        case .missing:
            text = Text("Monitored versions with ") + b("no file yet") + Text(" — ") + dot + Text(" missing. Search runs the engine across every monitored version.")
        case .cutoff:
            text = Text("A file exists but sits ") + b("below the profile cutoff") + Text(" — ") + dot + Text(" an upgrade is wanted. Search looks for a release that meets cutoff.")
        case .upcoming:
            text = Text("Movies ") + b("awaiting a release") + Text(" — ") + dot + Text(" in cinemas, or announced, but not yet out on digital/physical for your profile. (Upcoming ") + Text("episodes").italic() + Text(" live on the Calendar.)")
        case .fourk:
            text = Text("Titles you already own in ") + b("HD") + Text(" for which a genuine 2160p release has been ") + b("observed") + Text(" on your indexers — ") + dot + Text(" nothing is grabbed automatically. (This is ") + b("observe-only") + Text(": it reports what has been spotted during normal searches, off by default until turned on in Settings.)")
        }
        return text
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Lists

    @ViewBuilder
    private var wantedList: some View {
        if !feed.loaded && feed.error == nil {
            ActEmpty(message: "Loading wanted titles…")
        } else if feed.error != nil && feed.items.isEmpty {
            ActEmpty(message: "The wanted list could not be loaded. Check the backend and try again.")
        } else if feed.items.isEmpty {
            ActEmpty(message: search.isEmpty ? tab.emptyMessage : "No wanted titles match “\(search)”.")
        } else {
            // Flat: each card is a direct child of the page's lazy stack (a nested
            // LazyVStack made every scroll step re-measure the whole list).
            ForEach(Array(feed.items.enumerated()), id: \.element.id) { index, item in
                WantedCardView(item: item, tab: tab, interval: settings?.seasonSearchIntervalSeconds ?? 5)
                    .actReveal(index)
                    .padding(.top, index == 0 ? 6 : 11)
            }
            ActFooter(total: feed.total, loaded: feed.items.count, hasMore: feed.hasMore, loading: feed.loadingMore,
                      noun: tab.noun, query: search) { Task { await feed.loadMore() } }
        }
    }

    @ViewBuilder
    private var fourkList: some View {
        if !fourkFeed.loaded && fourkFeed.error == nil {
            ActEmpty(message: "Loading 4K availability…")
        } else if fourkFeed.error != nil && fourkFeed.items.isEmpty {
            ActEmpty(message: "The 4K availability feed could not be loaded. Check the backend and try again.")
        } else if fourkFeed.items.isEmpty {
            if !search.isEmpty {
                ActEmpty(message: "No 4K-available titles match “\(search)”.")
            } else {
                let observer = settings?.uhdAvailableObserverEnabled
                ActEmpty(message: observer == true
                         ? "Observing — nothing 4K spotted yet. Genuine 2160p releases seen during your normal searches will show up here."
                         : (observer == false ? "The 4K observer is off — turn it on to start spotting 4K." : "Nothing spotted yet."))
                if observer == false {
                    ObserverButton { await enableObserver() }
                        .frame(maxWidth: .infinity)
                        .padding(.top, -10)
                }
            }
        } else {
            ForEach(Array(fourkFeed.items.enumerated()), id: \.element.id) { index, item in
                WantedFourKCard(item: item) { addEditionFor = item }
                    .actReveal(index)
                    .padding(.top, index == 0 ? 6 : 11)
            }
            ActFooter(total: fourkFeed.total, loaded: fourkFeed.items.count, hasMore: fourkFeed.hasMore, loading: fourkFeed.loadingMore,
                      noun: tab.noun, query: search) { Task { await fourkFeed.loadMore() } }
        }
    }

    private func enableObserver() async {
        do {
            try await model.client?.updateActivitySettings(ActivitySettingsUpdate(uhdAvailableObserverEnabled: true))
            toaster.show("4K observing turned on.", tone: .success)
            settings = try? await model.client?.activitySettings()
            await fourkFeed.reload()
        } catch {
            toaster.error(error)
        }
    }
}

/// "Turn on observing" (ghost, 4K-tinted).
struct ObserverButton: View {
    let action: () async -> Void
    @State private var busy = false

    var body: some View {
        Button {
            busy = true
            Task { await action(); busy = false }
        } label: {
            Text(busy ? "Turning on…" : "Turn on observing").foregroundStyle(QualityTier.uhd.color)
        }
        .buttonStyle(ActButtonStyle(kind: .ghost))
        .disabled(busy)
    }
}
