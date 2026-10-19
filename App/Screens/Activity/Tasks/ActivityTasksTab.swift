import SwiftUI
import FusionhaKit

// Activity · Tasks (`routes/TasksTab.tsx`, `TasksTab.module.css`,
// `routes/tasks-format.ts`): the voice toggle, the System cards (Media
// enrichment / RSS Sync / Watchlists & lists / Scheduled), live backlog
// searches with Stop, Scanning and Queued runs, and the Recent timeline with
// each run's decision trail.

// MARK: - Store

@MainActor
@Observable
final class TasksStore {
    let feed = ActFeed<ActivityRun>(pageSize: 200) { _, _ in ([], 0) }
    var tasks: [ActivitySystemTask] = []
    var enrichment: ActivityEnrichmentStatus?
    /// The admin rollup behind the Watchlists & lists card (0.4.215); nil for others.
    var watchlists: RequestSourcesSummary?
    var isAdmin = false
    var playful = true

    var anyRunning: Bool {
        feed.items.contains { $0.status == "running" } || tasks.contains { $0.running }
            || (watchlists?.runningSources ?? 0) > 0
    }

    /// Recent (finished) runs grouped for the timeline, rebuilt only when the feed changes.
    @ObservationIgnored private var groupsCache: (revision: Int, groups: [TasksLogic.RunGroup])?
    var recentGroups: [TasksLogic.RunGroup] {
        let revision = feed.revision
        if let cache = groupsCache, cache.revision == revision { return cache.groups }
        // The three watchlist jobs live in their card, not in Recent (web `isWatchlistJobRun`).
        let groups = TasksLogic.groupRuns(feed.items.filter {
            $0.status != "running" && !WatchlistsTaskLogic.isWatchlistJobRun($0.name)
        })
        groupsCache = (revision, groups)
        return groups
    }

    func load(_ client: APIClient?) async {
        feed.source(client) { c, page, size in
            let r = try await c.systemRuns(page: page, pageSize: size)
            return (r.items, r.total)
        }
        await feed.reload()
        await refreshSide(client)
        if let settings = try? await client?.activitySettings() { playful = settings.voicePlayful ?? true }
    }

    func refresh(_ client: APIClient?) async {
        await feed.refreshLoaded()
        await refreshSide(client)
    }

    private func refreshSide(_ client: APIClient?) async {
        guard let client else { return }
        async let t = try? client.activitySystemTasks()
        async let e = try? client.activityEnrichmentStatus()
        if let tasks = await t { self.tasks = tasks }
        enrichment = await e
        if isAdmin, let summary = try? await client.requestSourcesSummary() { watchlists = summary }
    }
}

// MARK: - Tab

struct ActivityTasksTab: View {
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var store = TasksStore()
    /// The `?focus=<run_id>` deep-link target, kept while the tab shows.
    @State private var focusRunId: Int?

    var body: some View {
        let _ = PerfCount.hit("ActivityTasksTab.body")
        ActivityPage {
            if let focus = focusRunId {
                // Only a focus link pays for the reader (it wraps the lazy rows).
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 0) { pageContent }
                        .task(id: store.feed.loaded) { await scroll(proxy, to: focus) }
                }
            } else {
                pageContent
            }
        }
        .onChange(of: model.pendingTaskFocus, initial: true) {
            guard let id = model.pendingTaskFocus else { return }
            model.pendingTaskFocus = nil
            focusRunId = id
        }
        .animation(reduce ? nil : ActMotion.rows, value: store.feed.items.filter { $0.status == "running" }.map(\.id))
        .task {
            store.isAdmin = model.me?.hasPermission("system.admin") == true
            await store.load(model.client)
            // The web polls fast (2s) while any run is live, slowly otherwise.
            while await ActivityPoll.next(after: .seconds(store.anyRunning ? 2 : 15), model: model) {
                await store.refresh(model.client)
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        let feed = store.feed
        if !feed.loaded && feed.error == nil {
            ActEmpty(message: "Loading the task feed…")
        } else if feed.error != nil && feed.items.isEmpty {
            ActEmpty(message: "The task feed could not be loaded. Check the backend and try again.")
        } else {
            loadedView
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to runId: Int) async {
        guard store.feed.loaded else { return }
        try? await Task.sleep(for: .milliseconds(350))
        if reduce {
            proxy.scrollTo(TaskFocus.scrollId(runId), anchor: .center)
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(TaskFocus.scrollId(runId), anchor: .center) }
        }
    }

    @ViewBuilder
    private var loadedView: some View {
        let all = store.feed.items
        let items = all.filter { !WatchlistsTaskLogic.isWatchlistJobRun($0.name) }
        let running = items.filter { $0.status == "running" }
        let searchRuns = running.filter { $0.search != nil }
        let scanning = running.filter { $0.search == nil && $0.phase != nil && $0.phase != "queued" }
        let queued = running.filter { $0.search == nil && ($0.phase == nil || $0.phase == "queued") }
        let recent = items.filter { $0.status != "running" }
        let enrich = store.enrichment
        let showEnrichment = (enrich?.pendingFiles ?? 0) > 0 || (enrich?.issueFiles ?? 0) > 0
        let rssTask = store.tasks.first { TasksLogic.isRss($0.name) }
        let scheduled = TasksLogic.scheduledTasks(store.tasks)
        let watchlists = store.watchlists.flatMap { $0.sources.isEmpty ? nil : $0 }
        let showSystem = showEnrichment || rssTask != nil || !scheduled.isEmpty || watchlists != nil
        let folded = watchlists != nil && items.count < all.count

        if running.isEmpty && recent.isEmpty && !showSystem {
            ActEmpty(message: "No searches yet. RSS syncs, scheduled sweeps and searches show up here — each with what it grabbed and why.")
        } else {
            // Flat children of the page's lazy stack; the Recent timeline is one child per group.
            voiceToggle.padding(.bottom, 16)
            if showSystem {
                sectionLabel("System")
                VStack(spacing: 10) {
                    if showEnrichment, let enrich {
                        EnrichmentCard(status: enrich)
                        if let subs = enrich.subtasks, !subs.isEmpty {
                            EnrichmentSubtasksView(subtasks: subs) { await store.refresh(model.client) }
                        }
                    }
                    if let rssTask { RssSyncCard(task: rssTask, latestRun: items.first { $0.trigger == "rss" }) }
                    if let watchlists { WatchlistsTaskCard(summary: watchlists) }
                    if !scheduled.isEmpty { ScheduledCard(tasks: scheduled) }
                }
            }
            if let issues = enrich?.issues, !issues.isEmpty {
                sectionLabel("Needs attention").padding(.top, showSystem ? 22 : 0)
                EnrichmentAttentionView(issues: issues) { await store.refresh(model.client) }
            }
            if !searchRuns.isEmpty {
                sectionLabel("Searching").padding(.top, showSystem ? 22 : 0)
                VStack(spacing: 9) {
                    ForEach(searchRuns) { run in
                        SearchRunCard(run: run) { Task { await store.refresh(model.client) } }
                            .taskFocusFlash(run.id == focusRunId)
                            .id(TaskFocus.scrollId(run.id))
                            .actRowTransition(reduce)
                    }
                }
            }
            if !scanning.isEmpty {
                sectionLabel("Scanning").padding(.top, showSystem || !searchRuns.isEmpty ? 22 : 0)
                VStack(spacing: 9) {
                    ForEach(scanning) { run in
                        RunningRow(run: run, queued: false, playful: store.playful, focused: run.id == focusRunId)
                            .actRowTransition(reduce)
                    }
                }
            }
            if !queued.isEmpty {
                sectionLabel("Queued (\(queued.count))").padding(.top, !searchRuns.isEmpty || !scanning.isEmpty ? 22 : 0)
                VStack(spacing: 9) {
                    ForEach(queued) { run in
                        RunningRow(run: run, queued: true, playful: store.playful, focused: run.id == focusRunId)
                            .actRowTransition(reduce)
                    }
                }
            }
            if recent.isEmpty && folded {
                sectionLabel("Recent").padding(.top, 22)
                WatchlistsFoldedNote()
            }
            if !recent.isEmpty {
                let groups = store.recentGroups
                let last = groups.count - 1
                sectionLabel("Recent").padding(.top, !running.isEmpty || showSystem ? 22 : 0)
                if folded { WatchlistsFoldedNote() }
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    RecentGroupView(group: group, tasks: store.tasks, playful: store.playful, focusRunId: focusRunId)
                        .actReveal(index, stagger: 0.03)
                        .padding(.bottom, index == last ? 0 : 9)
                        .background(alignment: .topLeading) {
                            // The timeline thread behind the trigger icons (left 32), fading at the ends.
                            LinearGradient(stops: [.init(color: index == 0 ? .clear : Theme.line, location: 0),
                                                   .init(color: Theme.line, location: index == 0 ? 0.5 : 0),
                                                   .init(color: Theme.line, location: index == last ? 0.5 : 1),
                                                   .init(color: index == last ? .clear : Theme.line, location: 1)],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(width: 2)
                                .padding(.top, index == 0 ? 4 : 0)
                                .padding(.bottom, index == last ? 4 : 0)
                                .padding(.leading, 31)
                        }
                }
            }
            ActFooter(total: store.feed.total, loaded: store.feed.items.count, hasMore: store.feed.hasMore,
                      loading: store.feed.loadingMore, noun: "task runs") { Task { await store.feed.loadMore() } }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.66)
            .foregroundStyle(Theme.dim)
            .padding(.horizontal, 2)
            .padding(.top, 6)
            .padding(.bottom, 10)
    }

    /// `VoiceToggle`: Playful | Plain, right-aligned, persisted to `voice_playful`.
    private var voiceToggle: some View {
        let binding = Binding<Bool>(
            get: { store.playful },
            set: { newValue in
                store.playful = newValue
                Task {
                    do { try await model.client?.updateActivitySettings(ActivitySettingsUpdate(voicePlayful: newValue)) } catch { toaster.error(error) }
                }
            })
        return HStack {
            Spacer(minLength: 0)
            ActSegment(options: [(true, "Playful"), (false, "Plain")], selection: binding)
                .accessibilityLabel("Voice")
        }
    }
}
