import SwiftUI
import FusionhaKit

/// v2's Activity › Blocklist (plan S10, mock activity-log.js `blocklist` on
/// the tint ground). v1's feed, grouping and calls (`V2BlocklistModel`);
/// v2's look: the insight module with Retry, the reason chips (the
/// server's three categories), By title | Flat and the tools in one glass
/// capsule, then a W1 card per title (or one module of releases, flat).
/// Select mode brings a glass bar with Search again and Unblock. On the
/// open Duo a title fills the right page (`BlocklistTitlePane`).
struct V2BlocklistScope: View {
    let search: String
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(ActChrome.self) private var chrome
    @Environment(\.paneSize) private var pane
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
    @Environment(\.motionEnabled) private var motion
    @State private var data = V2BlocklistModel()
    /// Title cards opened or closed by hand (the first starts open).
    @State private var toggled: Set<String> = []
    @State private var picked: String?
    @State private var clearing = false
    @State private var releaseGroups = false

    private var split: V2ScopeSplit { V2ScopeSplit(width: pane.width, duoOpen: duoOpen, bookPose: bookPose) }

    var body: some View {
        @Bindable var chrome = chrome
        V2ScopeColumns(split: split) {
            V2ScopeList(gutter: split.gutter) {
                V2ScopeCaption(lead: data.feed.loaded ? "\(data.feed.total.formatted()) releases" : "Loading…",
                               rest: recoverableCaption)
            } content: { content }
        } right: {
            V2RightPage {
                if let group = openGroup {
                    BlocklistTitlePane(group: group, row: { row($0, nested: true) }).id(group.key)
                }
            }
        }
        .v2PageGround(art: nil)
        .searchable(text: $chrome.searchInput, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Search titles")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if data.selecting {
                V2BlocklistBulkBar(count: data.selected.count,
                                   hint: data.feed.hasMore ? "Select all covers the \(data.feed.items.count) loaded" : nil,
                                   selectAll: { data.selected = Set(data.filtered.map(\.id)) },
                                   searchAgain: { Task { await data.searchAgain(data.chosen, client: model.client, toaster: toaster) } },
                                   unblock: { unblock(data.chosen, search: false) })
            }
        }
        .toolbarVisibility(data.selecting ? .hidden : .automatic, for: .tabBar)
        .animation(motion ? .snappy(duration: 0.28) : nil, value: data.selecting)
        .animation(motion ? ActMotion.rows : nil, value: data.grouped)
        .task(id: search) { await data.load(model.client, search: search) }
        .onChange(of: data.category) { data.prune() }
        .onChange(of: data.feed.revision) { data.prune() }
        .confirmationDialog("Clear the whole blocklist?", isPresented: $clearing, titleVisibility: .visible) {
            Button("Clear blocklist", role: .destructive) { Task { await data.clearAll(model.client, toaster: toaster) } }
        } message: {
            Text("All \(ActFmt.plural(data.feed.total, "entry", "entries")) are removed, so every blocked release can be grabbed again. Nothing is deleted from disk; a release that is still bad blocklists itself again the next time it fails.")
        }
        .sheet(isPresented: $releaseGroups) {
            NavigationStack {
                ReleaseGroupBlocklistPanel()
                    .navigationTitle("Release groups")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", systemImage: "checkmark") { releaseGroups = false }
                        }
                    }
            }
            .environment(model)
        }
    }

    private var recoverableCaption: [String] {
        let n = data.counts[.recoverable] ?? 0
        return n > 0 ? ["\(n) can retry"] : []
    }

    @ViewBuilder
    private var content: some View {
        let feed = data.feed
        if !feed.loaded && feed.error == nil {
            ProgressView("Loading the blocklist…").frame(maxWidth: .infinity).padding(.top, 40)
        } else if feed.error != nil && feed.items.isEmpty {
            ContentUnavailableView("The blocklist could not be loaded", systemImage: "exclamationmark.icloud",
                                   description: Text("Check the server and try again."))
        } else if feed.items.isEmpty {
            if search.isEmpty {
                ContentUnavailableView("Nothing is blocklisted", systemImage: "nosign",
                                       description: Text("Releases you reject, or that fail, can be blocklisted so they are never grabbed again."))
            } else {
                ContentUnavailableView.search(text: search)
            }
        } else {
            loaded
        }
    }

    @ViewBuilder
    private var loaded: some View {
        @Bindable var data = data
        V2BlocklistInsight(loaded: data.feed.items.count, counts: data.counts, busy: data.busy) {
            Task { await data.retryRecoverable(model.client, toaster: toaster) }
        }
        .v2ScopeBlock()
        V2GlassChips(options: reasonChips, selection: $data.category).v2ScopeBlock()
        V2BlocklistTools(data: data, canClear: search.isEmpty, releaseGroups: { releaseGroups = true },
                         clear: { clearing = true })
            .v2ScopeBlock()
        let rows = data.filtered
        if rows.isEmpty {
            Text("No \(data.category.map { $0.label + " " } ?? "")releases in the loaded rows\(data.feed.hasMore ? " yet; load more below." : ".")")
                .font(.system(size: 13)).foregroundStyle(Theme.mut).padding(.vertical, 20)
        } else if data.grouped {
            let groups = BlocklistGrouping.titles(rows)
            ForEach(Array(groups.enumerated()), id: \.element.key) { index, group in
                V2BlocklistTitleCard(group: group, open: (index == 0) != toggled.contains(group.key),
                                     points: split.splits, selected: split.splits && group.key == openGroup?.key,
                                     toggle: { tap(group) }, row: { row($0, nested: true) })
                    .v2ScopeBlock(10)
            }
        } else {
            let releases = BlocklistGrouping.releases(rows)
            ForEach(Array(releases.enumerated()), id: \.element.key) { index, release in
                row(release, nested: false).v2ModuleRow(index, of: releases.count)
            }
        }
        ActFooter(total: data.feed.total, loaded: data.feed.items.count, hasMore: data.feed.hasMore,
                  loading: data.feed.loadingMore, noun: "blocklisted releases", query: search) {
            Task { await data.feed.loadMore() }
        }
    }

    private var reasonChips: [V2GlassChips<BlocklistCategory?>.Option] {
        let counts = data.counts
        var out: [V2GlassChips<BlocklistCategory?>.Option] = [.init(value: nil, label: "All", count: data.feed.items.count)]
        for category in [BlocklistCategory.recoverable, .manual, .permanent] where (counts[category] ?? 0) > 0 {
            out.append(.init(value: category, label: category.label, count: counts[category]))
        }
        return out
    }

    /// A release row; in select mode a tap checks every collapsed copy.
    private func row(_ release: BlocklistGrouping.Release, nested: Bool) -> AnyView {
        let checked = Set(release.ids).isSubset(of: data.selected)
        let view = V2BlocklistReleaseRow(release: release, nested: nested, showReasons: data.showReasons,
                                         selecting: data.selecting, checked: checked,
                                         unblock: { entries, search in unblock(entries, search: search) })
            .contentShape(Rectangle())
            .onTapGesture { if data.selecting { data.toggle(release.ids) } }
        return AnyView(view)
    }

    // MARK: Actions

    private var openGroup: BlocklistGrouping.Title? {
        guard split.splits else { return nil }
        let groups = BlocklistGrouping.titles(data.filtered)
        return groups.first { $0.key == picked } ?? groups.first
    }

    private func tap(_ group: BlocklistGrouping.Title) {
        withAnimation(motion ? .snappy(duration: 0.25) : nil) {
            if split.splits {
                picked = group.key
            } else if toggled.contains(group.key) {
                toggled.remove(group.key)
            } else {
                toggled.insert(group.key)
            }
        }
    }

    private func unblock(_ entries: [BlocklistEntry], search: Bool) {
        Task { await data.unblock(entries, search: search, client: model.client, toaster: toaster, motion: motion) }
    }
}
