import SwiftUI
import FusionhaKit

// The web's Wanted page (`routes/Wanted.tsx`, `Wanted.module.css`): the head with
// state-independent totals, the OverviewStrip, the Missing / Cutoff Unmet /
// Upcoming / 4K Available chips, search + "Search all", the lead, the per-title
// GroupCards (edition chips, context cue, search modes, missing episodes) and
// the 4K Available feed (see WantedFourK.swift).

enum WantedTab: String, CaseIterable, Hashable {
    case missing, cutoff, upcoming, fourk = "4k"

    var state: WantedState? {
        switch self {
        case .missing: return .missing
        case .cutoff: return .cutoffUnmet
        case .upcoming: return .upcoming
        case .fourk: return nil
        }
    }

    var label: String {
        switch self {
        case .missing: return "Missing"
        case .cutoff: return "Cutoff Unmet"
        case .upcoming: return "Upcoming"
        case .fourk: return "4K Available"
        }
    }

    var accent: Color {
        switch self {
        case .missing: return Theme.miss
        case .cutoff: return Theme.edition
        case .upcoming: return Theme.unaired
        case .fourk: return QualityTier.uhd.color
        }
    }

    var noun: String {
        switch self {
        case .missing: return "missing"
        case .cutoff: return "below cutoff"
        case .upcoming: return "upcoming"
        case .fourk: return "4K-available titles"
        }
    }

    var emptyMessage: String {
        switch self {
        case .missing: return "Nothing missing — every released or aired monitored version has a file."
        case .cutoff: return "Nothing below cutoff — every monitored file meets its profile cutoff."
        case .upcoming, .fourk: return "Nothing upcoming — no monitored version is waiting on a release or an air date."
        }
    }
}

/// The web's per-edition state vocabulary on the Wanted wire.
enum WantedLogic {
    static func stateColor(_ state: String) -> Color {
        switch state {
        case "missing": return Theme.miss
        case "cutoff_unmet": return Theme.edition
        case "upcoming": return Theme.unaired
        default: return Theme.done
        }
    }

    static func stateLabel(_ state: String) -> String {
        switch state {
        case "missing": return "Missing"
        case "cutoff_unmet": return "Cutoff unmet"
        case "upcoming": return "Upcoming"
        default: return "Have"
        }
    }

    static func kind(isAnime: Bool, kind: MediaKind) -> String {
        isAnime ? "anime" : (kind == .movie ? "movie" : "series")
    }

    static func primaryEdition(_ item: WantedItem, _ tab: WantedTab) -> WantedEdition? {
        item.editions.first { $0.state == tab.state?.rawValue } ?? item.editions.first
    }

    /// `contextCue`: the one fact that explains why this title is wanted.
    static func cue(_ item: WantedItem, _ e: WantedEdition) -> String {
        if e.state == "cutoff_unmet", let q = e.currentQuality { return "have \(ActFmt.quality(q))" }
        if item.kind == .movie {
            if e.state == "upcoming" {
                return e.upcomingUntil.map { "Upcoming until \(ActFmt.releaseDate($0))" } ?? "Upcoming"
            }
            if let released = e.releasedAt { return "Released \(ActFmt.relative(released))" }
            return lastSearch(e)
        }
        if e.state == "upcoming" { return "Next episode not yet aired" }
        let count = e.missingEpisodeCount ?? 0
        if count > 0 {
            let noun = count == 1 ? "episode" : "episodes"
            if let latest = e.latestAired { return "\(count) \(noun) aired · latest \(ActFmt.relative(latest))" }
            return "\(count) \(noun) aired"
        }
        return lastSearch(e)
    }

    private static func lastSearch(_ e: WantedEdition) -> String {
        e.lastSearch.map { "last search \(ActFmt.relative($0))" } ?? "never searched"
    }
}

/// The kind pill (`.kind[data-kind]`), 9.5/800 uppercase capsule.
struct WantedKindPill: View {
    let kind: String

    var body: some View {
        let tint: Color = kind == "movie" ? Theme.indigo : (kind == "series" ? Theme.cyan : Theme.anime)
        let text: Color = kind == "anime" ? Theme.anime : tint.mix(with: Theme.txt, by: kind == "movie" ? 0.4 : 0.38)
        Text(kind.uppercased())
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tint.opacity(kind == "movie" ? 0.14 : 0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(kind == "series" ? 0.32 : 0.34)))
            .fixedSize()
    }
}

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
        return ActFlow(spacing: 12, lineSpacing: 4) {
            Text("Wanted")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.txt)
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
private struct ObserverButton: View {
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

// MARK: - Wanted card

private struct WantedCardView: View {
    let item: WantedItem
    let tab: WantedTab
    let interval: Int
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var searchingKey: String?
    @State private var gradualRun: Int?
    @State private var gradualTotal = 0

    var body: some View {
        if let head = WantedLogic.primaryEdition(item, tab) {
            card(head)
        }
    }

    private func card(_ head: WantedEdition) -> some View {
        let kind = WantedLogic.kind(isAnime: item.isAnime, kind: item.kind)
        let tone = WantedLogic.stateColor(head.state == "missing" || head.state == "cutoff_unmet" || head.state == "upcoming" ? head.state : "missing")
        let nested = tab == .missing && item.kind == .series ? (head.missingEpisodes ?? []) : []
        let total = head.missingEpisodeCount ?? nested.count
        let extra = total - nested.count
        return ActGroupCard(wash: tone, base: Theme.panel, defaultOpen: true, hasTrailing: false) {
            ActPoster(url: item.posterUrl, title: item.title, size: .md)
        } title: {
            VStack(alignment: .leading, spacing: 5) {
                ActFlow(spacing: 9, lineSpacing: 4) {
                    Text(item.title).font(.system(size: 15, weight: .bold)).tracking(-0.15).foregroundStyle(Theme.txt)
                    WantedKindPill(kind: kind)
                    Text(WantedLogic.stateLabel(head.state)).font(.system(size: 12.5, weight: .bold)).foregroundStyle(WantedLogic.stateColor(head.state))
                }
                ActFlow(spacing: 8, lineSpacing: 4) {
                    ForEach(item.editions) { edition in editionChip(edition) }
                    Text("· \(WantedLogic.cue(item, head))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
            }
        } trailing: {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                detailRow
                if let gradualRun {
                    WantedGradualStrip(itemId: item.id, runId: gradualRun, fallbackTotal: gradualTotal, interval: interval) {
                        withAnimation(reduce ? nil : .easeOut(duration: 0.2)) { self.gradualRun = nil }
                    }
                    .transition(.opacity)
                }
                if !nested.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(nested.enumerated()), id: \.element.id) { index, ep in
                            if index > 0 { WantedDashedLine().padding(.horizontal, 0) }
                            episodeRow(ep)
                        }
                        if extra > 0 {
                            WantedDashedLine()
                            Text("+\(extra) more aired episode\(extra == 1 ? "" : "s") not shown")
                                .font(.system(size: 11.5))
                                .italic()
                                .foregroundStyle(Theme.dim)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                        }
                    }
                    .background(Theme.panel2)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
            }
        }
    }

    private func editionChip(_ edition: WantedEdition) -> some View {
        HStack(spacing: 6) {
            Circle().fill(WantedLogic.stateColor(edition.state)).frame(width: 6, height: 6)
            Text(edition.tier.chipLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.2)
                .foregroundStyle(edition.tier.color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
        .fixedSize()
        .accessibilityLabel("\(edition.tier.chipLabel) — \(WantedLogic.stateLabel(edition.state))")
    }

    private var detailRow: some View {
        HStack(spacing: 10) {
            Button {
                model.open(item.id)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.up.right.square").font(.system(size: 14))
                    Text("Open in library")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .frame(minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if tab == .missing || tab == .cutoff { searchModeMenu }
            ActMoreMenu {
                Button("Why this decision", systemImage: "list.bullet") { model.open(item.id) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// `SearchModeMenu`: Search all / Search missing only / Search each episode.
    private var searchModeMenu: some View {
        Menu {
            Button { run(label: item.title, key: "title") } label: {
                Text("Search all")
                Text("Every monitored version of this title — pack-preferred, missing + upgrades.")
            }
            if item.kind == .series {
                Button { Task { await startGradual(label: "\(item.title) (missing only)", missingOnly: true) } } label: {
                    Text("Search missing only")
                    Text("One at a time (~\(interval)s apart) in the background — just this title’s missing episodes.")
                }
                Button { Task { await startGradual(label: item.title, missingOnly: false) } } label: {
                    Text("Search each episode")
                    Text("Missing episodes plus any below cutoff, one at a time, ~\(interval)s apart.")
                }
            } else {
                Button { run(label: "\(item.title) (missing only)", key: "title", missingOnly: true) } label: {
                    Text("Search missing only")
                    Text("Just this title’s gaps — no upgrade re-checks.")
                }
            }
        } label: {
            ZStack {
                if searchingKey == "title" {
                    ProgressView().controlSize(.mini).tint(Theme.cyan)
                } else {
                    Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(Theme.mut)
            .frame(width: 30, height: 30)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Search for \(item.title)")
    }

    private func episodeRow(_ ep: WantedEpisode) -> some View {
        let key = "ep-\(ep.seasonNumber)-\(ep.episodeNumber)"
        return HStack(spacing: 12) {
            Text(ep.code)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .frame(minWidth: 58, alignment: .leading)
            Text(ep.title ?? "—")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let air = ep.airDate {
                Text(ActFmt.releaseDate(air)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim).fixedSize()
            }
            ActIconButton(systemImage: "magnifyingglass", label: "Search for \(item.title) \(ep.code)", tint: Theme.mut,
                          busy: searchingKey == key) {
                run(label: "\(item.title) \(ep.code)", key: key, episodeId: ep.id)
            }
            .padding(.vertical, -7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func run(label: String, key: String, episodeId: Int? = nil, missingOnly: Bool = false) {
        searchingKey = key
        Task {
            defer { searchingKey = nil }
            do {
                try await model.client?.runSearch(itemId: item.id, episodeId: episodeId, missingOnly: missingOnly)
                toaster.show("Searching for \(label)")
            } catch {
                toaster.error(error)
            }
        }
    }

    private func startGradual(label: String, missingOnly: Bool) async {
        guard let client = model.client else { return }
        do {
            let start = try await client.startGradualSearch(itemId: item.id, missingOnly: missingOnly)
            gradualTotal = start.total
            if start.total == 0 {
                toaster.show(missingOnly ? "\(label): no missing episodes — nothing to search"
                                         : "\(label): all episodes meet the cutoff — nothing to upgrade", tone: .warning)
            } else if let runId = start.runId {
                withAnimation(reduce ? nil : .easeOut(duration: 0.2)) { gradualRun = runId }
            }
        } catch let error as APIError where error.status == 409 && error.detailRunId != nil {
            withAnimation(reduce ? nil : .easeOut(duration: 0.2)) { gradualRun = error.detailRunId }
        } catch {
            toaster.show("Couldn't start the gradual search for \(label)", tone: .error)
        }
    }
}

/// `SeasonGradualProgress` for a whole title: "Searching episode n of N · next in Ns",
/// a bar and Stop. Polls the run every 1.5s until it settles.
private struct WantedGradualStrip: View {
    let itemId: Int
    let runId: Int
    let fallbackTotal: Int
    let interval: Int
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.actReduceMotion) private var reduce
    @State private var run: CommandRunDetail?
    @State private var stopping = false
    @State private var tickStamp = Date()

    var body: some View {
        let searching = run?.phase == "searching"
        let total = run?.progressTotal ?? fallbackTotal
        let current: Int? = searching ? run?.progressCurrent.map { $0 + 1 } : nil
        let detailText = run?.detail ?? ""
        let tail: String? = searching ? detailText.split(separator: "·").dropFirst().joined(separator: "·").trimmingCharacters(in: .whitespaces) : nil
        let pct = current.map { total > 0 ? min(1, Double($0) / Double(total)) : 0 } ?? 0
        HStack(spacing: 12) {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Theme.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .background(Circle().stroke(Theme.cyan.opacity(0.3), lineWidth: 2))
                .frame(width: 15, height: 15)
                .actSpin(true, duration: 0.8)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, interval - Int(context.date.timeIntervalSince(tickStamp)))
                let hasNext = current.map { $0 < total } ?? false
                (Text(current.map { "Searching episode \($0) of \(total)" } ?? "Starting gradual search…").foregroundColor(Theme.cyan).fontWeight(.semibold)
                 + Text((tail.flatMap { $0.isEmpty ? nil : " · \($0)" } ?? "") + (hasNext && remaining > 0 ? " · next in \(remaining)s" : ""))
                    .foregroundColor(Theme.mut))
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ActProgressBar(fraction: pct, height: 5, fill: AnyShapeStyle(Theme.cyan), shimmer: false)
                .frame(width: 80)
            Button {
                stopping = true
                Task { try? await model.client?.cancelGradualSearch(itemId: itemId); stopping = false }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 28, height: 28)
                    .background(Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.danger.opacity(0.3)))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(stopping)
            .accessibilityLabel(stopping ? "Stopping gradual search" : "Stop gradual search")
        }
        .padding(.leading, 15)
        .padding(.trailing, 6)
        .padding(.vertical, 3)
        .background(LinearGradient(stops: [.init(color: Theme.cyan.opacity(0.09), location: 0), .init(color: .clear, location: 0.8)],
                                   startPoint: .leading, endPoint: .trailing))
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .task(id: runId) {
            while !Task.isCancelled {
                do {
                    let detail = try await model.client?.systemRun(id: runId)
                    if detail?.progressCurrent != run?.progressCurrent || detail?.detail != run?.detail { tickStamp = Date() }
                    run = detail
                    if let status = detail?.status, status != "running" { onDone(); return }
                } catch {
                    onDone()
                    return
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }
}

/// A 1pt dashed separator (`border-bottom: 1px dashed var(--line)`).
private struct WantedDashedLine: View {
    var body: some View {
        Line()
            .stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}
