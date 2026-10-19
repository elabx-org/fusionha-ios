import SwiftUI
import FusionhaKit

// The web's Blocklist tab (`routes/activity/BlocklistTab.tsx`): insight card with
// reason categories + Retry recoverable, category / grouping segments, toolrow,
// grouped or flat release rows (copies sharing title + release + reason collapse
// to one ×N row), select mode scoped to the visible rows, and the clear dialog.

struct ActivityBlocklistTab: View {
    let search: String
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(ActBulk.self) private var bulk
    @Environment(\.actReduceMotion) private var reduce
    @State private var feed = ActFeed<BlocklistEntry> { _, _ in ([], 0) }
    @State private var category: BlocklistCategory?
    @State private var grouped = true
    @State private var showReasons = false
    @State private var selecting = false
    @State private var selected: Set<Int> = []
    @State private var clearing = false
    @State private var releaseGroups = false
    @State private var busy = false

    var body: some View {
        let _ = PerfCount.hit("ActivityBlocklistTab.body")
        ActivityPage {
            if !feed.loaded && feed.error == nil {
                ActEmpty(message: "Loading the blocklist…")
            } else if feed.error != nil && feed.items.isEmpty {
                ActEmpty(message: "The blocklist could not be loaded. Check the backend and try again.")
            } else if feed.items.isEmpty {
                ActEmpty(message: search.isEmpty
                         ? "Nothing is blocklisted. Releases you reject (or that fail) can be blocklisted so they are never grabbed again."
                         : "No blocklisted release matches “\(search)”.")
            } else {
                loadedView
            }
        }
        .animation(reduce ? nil : ActMotion.rows, value: RowsKey(category: category, grouped: grouped))
        .task(id: search) {
            // A new search invalidates the reason picked over the old rows.
            category = nil
            let q = search
            feed.source(model.client) { c, page, size in
                let r = try await c.blocklistPage(page: page, pageSize: size, query: q)
                return (r.items, r.total)
            }
            await feed.reload(resetting: true)
        }
        // Selection covers only visible rows: a filter change or a reload drops hidden ones.
        .onChange(of: category) { selected = BlocklistGrouping.pruned(selected, visible: filtered) }
        .onChange(of: feed.revision) { selected = BlocklistGrouping.pruned(selected, visible: filtered) }
        .onChange(of: selecting) { publishBulk() }
        .onChange(of: selected) { publishBulk() }
        .onDisappear { bulk.config = nil }
        .sheet(isPresented: $clearing) {
            let n = feed.total
            ActDialog(title: "Clear the whole blocklist?",
                      message: "All \(n) \(n == 1 ? "entry" : "entries") will be removed, so every previously-blocked release becomes grabbable again. Nothing is deleted from disk — a release that is still genuinely bad will simply re-blocklist the next time it fails.",
                      confirmLabel: busy ? "Clearing…" : "Clear blocklist", busy: busy,
                      onCancel: { clearing = false },
                      onConfirm: { Task { await clearAll() } }) { EmptyView() }
        }
        .sheet(isPresented: $releaseGroups) {
            NavigationStack {
                ReleaseGroupBlocklistPanel()
                    .navigationTitle("Release groups")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { SheetDoneButton { releaseGroups = false } } }
                    .closeOnlyBars()
            }
        }
    }

    private struct RowsKey: Equatable {
        let category: BlocklistCategory?
        let grouped: Bool
    }

    private var counts: [BlocklistCategory: Int] {
        Dictionary(grouping: feed.items) { BlocklistCategory(reason: $0.reason) }.mapValues(\.count)
    }

    private var filtered: [BlocklistEntry] {
        guard let category else { return feed.items }
        return feed.items.filter { BlocklistCategory(reason: $0.reason) == category }
    }

    /// Flat children of the page's lazy stack (one per card).
    @ViewBuilder
    private var loadedView: some View {
        BlocklistInsight(total: feed.total, counts: counts, busy: busy) { await retryRecoverable() }
            .padding(.bottom, 14)
        filterBar.padding(.bottom, 8)
        toolrow.padding(.bottom, 12)
        let rows = filtered
        if rows.isEmpty {
            ActEmpty(message: "No \(category.map { $0.label + " " } ?? "")releases in the loaded rows\(feed.hasMore ? " yet — load more below." : ".")")
        } else if grouped {
            let groups = BlocklistGrouping.titles(rows)
            let last = groups.count - 1
            ForEach(Array(groups.enumerated()), id: \.element.key) { index, group in
                BlocklistTitleCard(group: group) { release in row(release, nested: true) }
                    .actReveal(index)
                    .padding(.bottom, index == last ? 0 : 10)
                    .actRowTransition(reduce)
            }
        } else {
            let groups = BlocklistGrouping.releases(rows)
            let last = groups.count - 1
            ForEach(Array(groups.enumerated()), id: \.element.key) { index, release in
                row(release, nested: false).actReveal(index)
                    .padding(.bottom, index == last ? 0 : 10)
                    .actRowTransition(reduce)
            }
        }
        ActFooter(total: feed.total, loaded: feed.items.count, hasMore: feed.hasMore, loading: feed.loadingMore,
                  noun: "blocklisted releases", query: search) { Task { await feed.loadMore() } }
    }

    private var filterBar: some View {
        let c = counts
        // Only the categories present get a segment (web `BLOCKLIST_FILTER_ORDER` filter).
        let cats = [BlocklistCategory.recoverable, .manual, .permanent].filter { (c[$0] ?? 0) > 0 }
        var options: [(BlocklistCategory?, String)] = [(nil, "All \(feed.items.count)")]
        for cat in cats { options.append((cat, "\(cat.label) \(c[cat] ?? 0)")) }
        return VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                ActSegment(options: options, selection: $category)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                ActSegment(options: [(true, "Group by title"), (false, "Flat list")], selection: $grouped)
            }
        }
    }

    private var toolrow: some View {
        ActFlow(spacing: 12, lineSpacing: 8) {
            Text("\(ActFmt.plural(feed.total, "blocklisted release")) — never grabbed again")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
            Toggle("Show reasons", isOn: $showReasons)
                .toggleStyle(.button)
                .font(.system(size: 12))
                .tint(Theme.indigo)
            Button(selecting ? "Done" : "Select") {
                selecting.toggle()
                if !selecting { selected = [] }
            }
            .buttonStyle(ActButtonStyle(kind: .ghost))
            Button("Clear blocklist") { clearing = true }
                .buttonStyle(ActButtonStyle(kind: .ghost))
                .foregroundStyle(Theme.danger)
                .disabled(!search.isEmpty)
            Button("Release groups →") { releaseGroups = true }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .buttonStyle(.plain)
        }
    }

    /// A collapsed ×N row acts on every copy: unblock and select cover them all,
    /// or the release stays blocked (web `BlocklistReleaseRow` removeAll / setMany).
    @ViewBuilder
    private func row(_ release: BlocklistGrouping.Release, nested: Bool) -> some View {
        let ids = Set(release.ids)
        let checked = ids.isSubset(of: selected)
        let content = BlocklistRowView(entry: release.lead, nested: nested, copies: release.entries, showReasons: showReasons,
                                       selecting: selecting, checked: checked,
                                       unblock: { search in Task { await unblock(release.entries, search: search) } },
                                       removeCopy: { copy in Task { await unblock([copy], search: false) } })
        if selecting {
            content.contentShape(Rectangle()).onTapGesture {
                if checked { selected.subtract(ids) } else { selected.formUnion(ids) }
            }
        } else {
            content
        }
    }

    // MARK: Actions

    private func unblock(_ entries: [BlocklistEntry], search: Bool) async {
        guard let client = model.client, !entries.isEmpty else { return }
        do {
            try await BlocklistOps.remove(client, entries, search: search)
            if reduce { feed.remove { e in entries.contains { $0.id == e.id } } } else {
                withAnimation(ActMotion.rows) { feed.remove { e in entries.contains { $0.id == e.id } } }
            }
            selected.subtract(entries.map(\.id))
            if entries.count == 1 {
                toaster.show(search ? "Un-blocklisted, searching for a replacement" : "Removed from the blocklist", tone: .success)
            } else {
                toaster.show("Removed \(ActFmt.plural(entries.count, "release")) from the blocklist", tone: .success)
            }
        } catch {
            toaster.error(error)
        }
    }

    private func retryRecoverable() async {
        let recoverable = feed.items.filter { BlocklistCategory(reason: $0.reason) == .recoverable }
        guard !recoverable.isEmpty, let client = model.client else { return }
        busy = true
        defer { busy = false }
        do {
            try await BlocklistOps.remove(client, recoverable, search: true)
            toaster.show("Un-blocklisted \(recoverable.count) dead-NZB release\(recoverable.count == 1 ? "" : "s") — re-searching", tone: .success)
            await feed.refreshLoaded()
        } catch {
            toaster.error(error)
        }
    }

    private func clearAll() async {
        guard let client = model.client else { return }
        busy = true
        defer { busy = false }
        do {
            let r = try await client.clearBlocklist()
            clearing = false
            toaster.show("Cleared \(r.deleted) blocklist \(r.deleted == 1 ? "entry" : "entries").", tone: .success)
            await feed.reload()
        } catch {
            clearing = false
            toaster.error(error)
        }
    }

    private func publishBulk() {
        guard selecting else { bulk.config = nil; return }
        let count = selected.count
        bulk.config = ActBulk.Config(
            count: count,
            hint: feed.hasMore ? "Select all covers the \(feed.items.count) loaded — scroll to load the rest" : nil,
            onSelectAll: { selected = Set(filtered.map(\.id)) },
            actions: [
                ActBulk.Action(label: "Remove from blocklist", kind: .danger, disabled: count == 0) {
                    let chosen = filtered.filter { selected.contains($0.id) }
                    Task { await unblock(chosen, search: false) }
                },
            ])
    }
}
