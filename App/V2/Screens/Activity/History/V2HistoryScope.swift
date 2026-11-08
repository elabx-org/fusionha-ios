import SwiftUI
import FusionhaKit

/// v2's Activity › History (plan S10, mock activity-log.js `history` on the
/// W1 ground). v1's feed, story building and actions; v2's look: the
/// insight module, glass filter chips, Stories | Raw log as a segmented
/// picker, the stories as rows of one module and the raw log as another.
/// A story's Lifecycle opens as a sheet on the phone; on the open Duo the
/// chosen story's lifecycle fills the right page, and the raw log runs
/// across the whole display.
struct V2HistoryScope: View {
    let search: String
    let itemId: Int?
    @Environment(AppModel.self) private var model
    @Environment(ActChrome.self) private var chrome
    @Environment(\.paneSize) private var pane
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
    @Environment(\.motionEnabled) private var motion
    @State private var feed = ActFeed<HistoryEntry> { _, _ in ([], 0) }
    @State private var sparkline: [HistorySparklineDay] = []
    @State private var raw = false
    @State private var storyFilter: HistoryStoryType?
    @State private var rawFilter: String?
    @State private var derived = HistoryDerived()
    /// The story on the right page (open Duo); nil = the first.
    @State private var picked: String?
    @State private var lifecycleSheet: HistoryStory?

    private var split: V2ScopeSplit { V2ScopeSplit(width: pane.width, duoOpen: duoOpen, bookPose: bookPose) }
    private var splits: Bool { split.splits && !raw }

    private var shownStories: [HistoryStory] {
        storyFilter.map { f in derived.stories.filter { $0.type == f } } ?? derived.stories
    }

    private var openStory: HistoryStory? {
        let shown = shownStories
        if let picked, let story = shown.first(where: { $0.key == picked }) { return story }
        return shown.first { $0.mediaItemId != nil }
    }

    var body: some View {
        @Bindable var chrome = chrome
        V2ScopeColumns(split: split, enabled: !raw) {
            V2ScopeList(gutter: split.gutter) {
                V2ScopeCaption(lead: feed.loaded ? "\(feed.total.formatted()) events" : "Loading…",
                               rest: sparkline.last.map { ["\($0.count.formatted()) today"] } ?? [])
            } content: {
                content
            }
        } right: {
            V2RightPage {
                if let story = openStory {
                    HistoryLifecyclePane(story: story, onChanged: refresh).id(story.key)
                } else {
                    ContentUnavailableView("Pick a story", systemImage: "clock",
                                           description: Text("Its lifecycle shows here."))
                }
            }
        }
        .v2PageGround(art: groundArt)
        .searchable(text: $chrome.searchInput, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Search titles")
        .animation(motion ? .snappy(duration: 0.25) : nil, value: raw)
        .task(id: "\(search)|\(itemId ?? 0)") { await load() }
        .task(id: feed.revision) { await rebuild() }
        .sheet(item: $lifecycleSheet) { story in
            HistoryLifecycleSheetV2(story: story, onChanged: refresh).environment(model)
        }
        // Fold continuity: the picked story moves between the right page and its sheet.
        .foldPick(splits: splits, picked: $picked, sheet: $lifecycleSheet, id: \.key) { key in
            shownStories.first { $0.key == key }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let filter = chrome.itemFilter {
            HistoryItemFilterChip(filter: filter) { chrome.itemFilter = nil }.v2ScopeBlock()
        }
        if (!feed.loaded && feed.error == nil) || (derived.revision < 0 && !feed.items.isEmpty) {
            ProgressView("Loading history…").frame(maxWidth: .infinity).padding(.top, 40)
        } else if feed.error != nil && feed.items.isEmpty {
            ContentUnavailableView("History could not be loaded", systemImage: "exclamationmark.icloud",
                                   description: Text("Check the server and try again."))
        } else if feed.items.isEmpty {
            if search.isEmpty {
                ContentUnavailableView("No history yet", systemImage: "clock",
                                       description: Text("Grabs, imports, upgrades and failures show up here."))
            } else {
                ContentUnavailableView.search(text: search)
            }
        } else {
            loaded
        }
    }

    @ViewBuilder
    private var loaded: some View {
        if raw {
            V2HistoryRawStrip(counts: derived.rawCounts).v2ScopeBlock()
        } else {
            V2HistoryInsight(total: feed.total, counts: derived.storyCounts, sparkline: sparkline).v2ScopeBlock()
        }
        Picker("Show", selection: $raw) {
            Text("Stories").tag(false)
            Text("Raw log").tag(true)
        }
        .pickerStyle(.segmented)
        .v2ScopeBlock()
        if raw {
            V2GlassChips(options: V2HistoryFilters.raw(derived.rawCounts, all: feed.items.count), selection: $rawFilter)
                .v2ScopeBlock()
            rawRows
        } else {
            V2GlassChips(options: V2HistoryFilters.story(derived.storyCounts, all: derived.stories.count),
                         selection: $storyFilter)
                .v2ScopeBlock()
            storyRows
        }
        ActFooter(total: feed.total, loaded: feed.items.count, hasMore: feed.hasMore, loading: feed.loadingMore,
                  noun: "events", query: search) { Task { await feed.loadMore() } }
    }

    @ViewBuilder
    private var storyRows: some View {
        let shown = shownStories
        if shown.isEmpty {
            Text("No \(storyFilter.map { $0.label.lowercased() + " " } ?? "")stories in the loaded rows\(feed.hasMore ? " yet; load more below." : ".")")
                .font(.system(size: 13)).foregroundStyle(Theme.mut).padding(.vertical, 20)
        } else {
            let open = splits ? openStory?.key : nil
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, story in
                VStack(alignment: .leading, spacing: 0) {
                    if index == 0 { V2ModuleCaption(text: "Latest first", systemImage: "clock") }
                    V2HistoryStoryCard(story: story, lean: splits, openLifecycle: { openLifecycle(story) },
                                       onChanged: refresh)
                }
                .contentShape(Rectangle())
                .onTapGesture { select(story) }
                .v2ModuleRow(index, of: shown.count, selected: story.key == open)
                .foldRow("story.\(story.id)")
            }
        }
    }

    @ViewBuilder
    private var rawRows: some View {
        let rows = rawFilter.map { f in feed.items.filter { HistoryLogic.rawFilter($0.eventType) == f } } ?? feed.items
        let wide = split.splits
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
            V2HistoryRawRow(entry: entry, wide: wide)
                .contentShape(Rectangle())
                .onTapGesture { if let id = entry.mediaItemId { model.open(id) } }
                .v2ModuleRow(index, of: rows.count)
                .foldRow("event.\(entry.id)")
        }
    }

    // MARK: Actions

    private func select(_ story: HistoryStory) {
        if splits {
            withAnimation(motion ? .snappy(duration: 0.25) : nil) { picked = story.key }
        } else if let id = story.mediaItemId {
            model.open(id)
        }
    }

    private func openLifecycle(_ story: HistoryStory) {
        if splits {
            withAnimation(motion ? .snappy(duration: 0.25) : nil) { picked = story.key }
        } else {
            lifecycleSheet = story
        }
    }

    private func refresh() {
        Task { await feed.refreshLoaded() }
    }

    /// The latest event's title (the chosen story's on the open Duo).
    private var groundArt: URL? {
        let story = splits ? openStory : derived.stories.first
        guard let story else { return nil }
        let backdrop = story.mediaItemId.flatMap { id in model.library.first { $0.id == id }?.backdropUrl }
        return PageArtSource.url(backdrop: backdrop, poster: story.posterUrl)
    }

    private func load() async {
        let client = model.client
        let q = search, item = itemId
        feed.source(client) { c, page, size in
            let r = try await c.historyPage(page: page, pageSize: size, query: q, itemId: item)
            return (r.items, r.total)
        }
        await feed.reload(resetting: true)
        if let days = try? await client?.historySparkline(days: 14) { sparkline = days }
    }

    /// Stories, counts and filters, derived once per feed change off the main actor.
    private func rebuild() async {
        let items = feed.items
        let revision = feed.revision
        let next = await Task.detached(priority: .userInitiated) {
            HistoryDerived.make(items, revision: revision)
        }.value
        guard !Task.isCancelled, revision == feed.revision else { return }
        derived = next
    }
}
