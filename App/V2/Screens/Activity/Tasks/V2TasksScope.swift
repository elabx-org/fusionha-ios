import SwiftUI
import FusionhaKit

/// v2's Activity › Tasks (plan S10, mock activity-log.js `tasks`). v1's
/// store, polling and pieces (`TasksStore`, `SearchRunCard`, `RunningRow`,
/// `RunTrail`, the enrichment and watchlist cards); v2's look: the voice as a
/// segmented picker, RSS sync as a module, live runs, then Recent as one W1
/// module. A tapped run opens `TaskRunPane`: beside the list on the open Duo
/// (whose right page otherwise holds the System modules), in a sheet on the
/// phone. A `?focus=` run link opens that run the same way.
struct V2TasksScope: View {
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.paneSize) private var pane
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
    @Environment(\.motionEnabled) private var motion
    @State private var store = TasksStore()
    /// The run on the open Duo's right page.
    @State private var picked: Int?
    @State private var sheetRun: ActivityRun?
    /// Recent groups whose earlier runs show.
    @State private var unfolded: Set<String> = []
    /// The `?focus=<run_id>` target, kept until its run has loaded.
    @State private var focusRunId: Int?
    @State private var focusPending = false

    private var split: V2ScopeSplit { V2ScopeSplit(width: pane.width, duoOpen: duoOpen, bookPose: bookPose) }

    var body: some View {
        V2ScopeColumns(split: split) {
            V2ScopeList(gutter: split.gutter) {
                V2ScopeCaption(lead: captionLead, rest: captionRest)
            } content: { content }
        } right: {
            V2RightPage { rightPage }
        }
        .v2PageGround(art: nil)
        .refreshable { await store.refresh(model.client) }
        .animation(motion ? ActMotion.rows : nil, value: runningIds)
        .onChange(of: model.pendingTaskFocus, initial: true) {
            guard let id = model.pendingTaskFocus else { return }
            model.pendingTaskFocus = nil
            focusRunId = id
            focusPending = true
            applyFocus()
        }
        .onChange(of: store.feed.revision) { applyFocus() }
        .task {
            store.isAdmin = model.me?.hasPermission("system.admin") == true
            await store.load(model.client)
            applyFocus()
            // v1's rhythm: every 2s while a run is live, 15s otherwise.
            while await ActivityPoll.next(after: .seconds(store.anyRunning ? 2 : 15), model: model) {
                await store.refresh(model.client)
            }
        }
        .sheet(item: $sheetRun) { run in
            V2ScopeSheet(title: run.name) {
                TaskRunPane(run: run, tasks: store.tasks, playful: store.playful)
            }
            .environment(model)
        }
        // Fold continuity: the picked run moves between the right page and its sheet.
        .foldPick(splits: split.splits, picked: $picked, sheet: $sheetRun, id: \.id) { [store] id in
            store.feed.items.first { $0.id == id }
        }
    }

    // MARK: Caption

    private var runningIds: [Int] { store.feed.items.filter { $0.status == "running" }.map(\.id) }

    private var captionLead: String {
        guard store.feed.loaded else { return "Loading…" }
        let n = runningIds.count
        return n == 0 ? "Nothing running" : "\(n) running"
    }

    private var captionRest: [String] {
        guard let rss = store.tasks.first(where: { TasksLogic.isRss($0.name) }) else { return [] }
        if rss.running { return ["RSS sync running"] }
        return V2QueueTime.clock(rss.nextRun).map { ["RSS sync next at \($0)"] } ?? []
    }

    // MARK: Left page

    @ViewBuilder
    private var content: some View {
        let feed = store.feed
        if !feed.loaded && feed.error == nil {
            ProgressView("Loading the task feed…").frame(maxWidth: .infinity).padding(.top, 40)
        } else if feed.error != nil && feed.items.isEmpty {
            ContentUnavailableView("The task feed could not be loaded", systemImage: "exclamationmark.icloud",
                                   description: Text("Check the server and try again."))
        } else if feed.items.isEmpty && !V2TaskSystem.hasContent(store) {
            ContentUnavailableView("No searches yet", systemImage: "clock.arrow.circlepath",
                                   description: Text("RSS syncs, scheduled sweeps and searches show up here, each with what it grabbed and why."))
        } else {
            loaded
        }
    }

    @ViewBuilder
    private var loaded: some View {
        let all = store.feed.items
        let items = all.filter { !WatchlistsTaskLogic.isWatchlistJobRun($0.name) }
        let running = items.filter { $0.status == "running" }
        voicePicker.v2ScopeBlock()
        if split.splits {
            let parts = V2TaskSystem.Parts(store)
            if let rss = parts.rss {
                V2RssModule(task: rss, latest: parts.latestRss).v2ScopeBlock()
            }
        } else {
            V2TaskSystem(store: store).v2ScopeBlock(18)
        }
        runningSections(running)
        recent(folded: store.watchlists.map { !$0.sources.isEmpty } == true && items.count < all.count)
        ActFooter(total: store.feed.total, loaded: store.feed.items.count, hasMore: store.feed.hasMore,
                  loading: store.feed.loadingMore, noun: "task runs") { Task { await store.feed.loadMore() } }
    }

    /// v1's Playful | Plain, persisted to `voice_playful`.
    private var voicePicker: some View {
        let binding = Binding<Bool>(
            get: { store.playful },
            set: { newValue in
                store.playful = newValue
                Task {
                    do { try await model.client?.updateActivitySettings(ActivitySettingsUpdate(voicePlayful: newValue)) } catch { toaster.error(error) }
                }
            })
        return Picker("Voice", selection: binding) {
            Text("Playful").tag(true)
            Text("Plain").tag(false)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
    }

    /// Searching (v1's cards with Stop), Scanning and Queued.
    @ViewBuilder
    private func runningSections(_ running: [ActivityRun]) -> some View {
        let searchRuns = running.filter { $0.search != nil }
        let scanning = running.filter { $0.search == nil && $0.phase != nil && $0.phase != "queued" }
        let queued = running.filter { $0.search == nil && ($0.phase == nil || $0.phase == "queued") }
        if !searchRuns.isEmpty {
            V2ScopeSectionHead(title: "Searching", systemImage: "magnifyingglass").v2ScopeBlock(8)
            ForEach(searchRuns) { run in
                SearchRunCard(run: run) { Task { await store.refresh(model.client) } }
                    .taskFocusFlash(run.id == focusRunId)
                    .v2ScopeBlock(9)
            }
        }
        if !scanning.isEmpty {
            V2ScopeSectionHead(title: "Scanning", systemImage: "waveform").v2ScopeBlock(8)
            ForEach(scanning) { run in
                RunningRow(run: run, queued: false, playful: store.playful, focused: run.id == focusRunId).v2ScopeBlock(9)
            }
        }
        if !queued.isEmpty {
            V2ScopeSectionHead(title: "Queued (\(queued.count))", systemImage: "hourglass").v2ScopeBlock(8)
            ForEach(queued) { run in
                RunningRow(run: run, queued: true, playful: store.playful, focused: run.id == focusRunId).v2ScopeBlock(9)
            }
        }
    }

    /// Recent as one W1 module; the watchlist jobs live in their card.
    @ViewBuilder
    private func recent(folded: Bool) -> some View {
        let rows = V2TaskRecentRows.entries(store.recentGroups, unfolded: unfolded)
        if !rows.isEmpty || folded {
            V2ScopeSectionHead(title: "Recent", systemImage: "clock").v2ScopeBlock(8)
            if folded { WatchlistsFoldedNote().v2ScopeBlock(10) }
        }
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
            V2TaskRunRow(run: entry.run, playful: store.playful, earlier: entry.earlier,
                         showsEarlier: unfolded.contains(entry.groupKey), nestedEarlier: entry.nested,
                         points: split.splits, open: { show(entry.run) },
                         toggleEarlier: entry.earlier > 0 ? { toggle(entry.groupKey) } : nil)
                .v2ModuleRow(index, of: rows.count, selected: split.splits && entry.run.id == pickedRun?.id)
        }
    }

    // MARK: Right page

    @ViewBuilder
    private var rightPage: some View {
        if let run = pickedRun {
            TaskRunPane(run: run, tasks: store.tasks, playful: store.playful, close: { pick(nil) }).id(run.id)
        } else if store.feed.loaded && V2TaskSystem.hasContent(store, includeRss: false) {
            V2ScopeSectionHead(title: "System", systemImage: "gearshape.2")
            V2TaskSystem(store: store, includeRss: false)
        } else if store.feed.loaded {
            Text("Pick a run to see what it evaluated and why.")
                .font(.system(size: 14)).foregroundStyle(Theme.mut).padding(.top, 40)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Actions

    private var pickedRun: ActivityRun? {
        guard split.splits, let picked else { return nil }
        return store.feed.items.first { $0.id == picked }
    }

    private func show(_ run: ActivityRun) {
        if split.splits { pick(run.id) } else { sheetRun = run }
    }

    private func pick(_ id: Int?) {
        withAnimation(motion ? .snappy(duration: 0.25) : nil) { picked = id }
    }

    private func toggle(_ key: String) {
        withAnimation(motion ? .snappy(duration: 0.25) : nil) {
            if unfolded.contains(key) { unfolded.remove(key) } else { unfolded.insert(key) }
        }
    }

    /// Opens the focused run once it has loaded, once; a live one flashes
    /// in place (v1 keeps the flash target while the tab shows).
    private func applyFocus() {
        guard focusPending, let id = focusRunId, store.feed.loaded,
              let run = store.feed.items.first(where: { $0.id == id }) else { return }
        focusPending = false
        guard run.status != "running" else { return }
        if let key = store.recentGroups.first(where: { $0.older.contains { $0.id == id } })?.key { unfolded.insert(key) }
        show(run)
    }
}
