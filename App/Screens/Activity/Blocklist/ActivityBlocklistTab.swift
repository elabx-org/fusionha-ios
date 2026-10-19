import SwiftUI
import FusionhaKit

// The web's Blocklist tab (`routes/activity/BlocklistTab.tsx`): insight card with
// reason categories + Retry recoverable, category / grouping segments, toolrow,
// grouped or flat release rows, select mode and the clear dialog.

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
            let q = search
            feed.source(model.client) { c, page, size in
                let r = try await c.blocklistPage(page: page, pageSize: size, query: q)
                return (r.items, r.total)
            }
            await feed.reload(resetting: true)
        }
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
        insight.padding(.bottom, 14)
        filterBar.padding(.bottom, 8)
        toolrow.padding(.bottom, 12)
        let rows = filtered
        if rows.isEmpty {
            ActEmpty(message: "No \(category?.label ?? "") releases in the loaded rows.")
        } else if grouped {
            let groups = Self.group(rows)
            let last = groups.count - 1
            ForEach(Array(groups.enumerated()), id: \.element.key) { index, group in
                groupCard(group).actReveal(index)
                    .padding(.bottom, index == last ? 0 : 10)
                    .actRowTransition(reduce)
            }
        } else {
            let last = rows.count - 1
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                row(entry, nested: false, copies: [entry]).actReveal(index)
                    .padding(.bottom, index == last ? 0 : 10)
                    .actRowTransition(reduce)
            }
        }
        ActFooter(total: feed.total, loaded: feed.items.count, hasMore: feed.hasMore, loading: feed.loadingMore,
                  noun: "blocklisted releases", query: search) { Task { await feed.loadMore() } }
    }

    // MARK: Insight

    private var insight: some View {
        let c = counts
        let recoverable = c[.recoverable] ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            ActFlow(spacing: 22, lineSpacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(feed.total)").font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.txt)
                        .contentTransition(.numericText(value: Double(feed.total)))
                    Text("BLOCKLISTED · NEVER RE-GRABBED").font(.system(size: 11, weight: .semibold)).tracking(0.5).foregroundStyle(Theme.dim)
                }
                ForEach([BlocklistCategory.recoverable, .manual, .permanent], id: \.self) { cat in
                    HStack(spacing: 8) {
                        Image(systemName: cat.icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(cat.color)
                            .frame(width: 24, height: 24).background(cat.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                        Text("\(c[cat] ?? 0)").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                        Text(cat == .recoverable ? "dead NZB" : (cat == .manual ? "manual" : "bad content"))
                            .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if recoverable > 0 {
                HStack(spacing: 10) {
                    (Text("\(recoverable) dead-NZB").bold().foregroundColor(Theme.txt)
                     + Text(" may have recovered. Retry to re-check the source"))
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    Spacer(minLength: 0)
                    ActAsyncButton(label: "Retry recoverable", kind: .amber, externalWorking: busy) {
                        await retryRecoverable(); return true
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private var filterBar: some View {
        let c = counts
        return VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                ActSegment(options: [(BlocklistCategory?.none, "All \(feed.items.count)"),
                                     (.recoverable, "Dead NZB \(c[.recoverable] ?? 0)"),
                                     (.manual, "Manual \(c[.manual] ?? 0)"),
                                     (.permanent, "Bad content \(c[.permanent] ?? 0)")],
                           selection: $category)
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
        }
    }

    // MARK: Groups + rows

    struct TitleGroup {
        let key: String
        let entries: [BlocklistEntry]
    }

    static func group(_ rows: [BlocklistEntry]) -> [TitleGroup] {
        var order: [String] = []
        var map: [String: [BlocklistEntry]] = [:]
        for row in rows {
            let key = row.mediaItemId.map { "item:\($0)" } ?? "title:\(row.itemTitle ?? row.title)"
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(row)
        }
        return order.map { TitleGroup(key: $0, entries: map[$0] ?? []) }
    }

    private func groupCard(_ group: TitleGroup) -> some View {
        let lead = group.entries[0]
        let newest = group.entries.compactMap { ActFmt.date($0.createdAt) }.max()
        // Collapse exact duplicates (same release) into one row with ×N.
        var copies: [String: [BlocklistEntry]] = [:]
        var unique: [BlocklistEntry] = []
        for e in group.entries {
            let k = e.sourceTitle ?? e.title
            if copies[k] == nil { unique.append(e) }
            copies[k, default: []].append(e)
        }
        return ActGroupCard(wash: nil, base: Theme.panel) {
            ActPoster(url: lead.posterUrl, title: lead.itemTitle ?? lead.title, size: .md)
        } title: {
            VStack(alignment: .leading, spacing: 5) {
                Text(lead.itemTitle ?? "Unknown title").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                    .onTapGesture { if let id = lead.mediaItemId { model.open(id) } }
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 1).fill(Theme.danger).frame(width: 6, height: 6)
                    Text("\(group.entries.count) blocked")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
            }
        } trailing: {
            Text(newest.map { ActFmt.relative($0) } ?? "").font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim)
        } content: {
            VStack(spacing: 0) {
                ForEach(Array(unique.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                    row(entry, nested: true, copies: copies[entry.sourceTitle ?? entry.title] ?? [entry])
                }
            }
        }
    }

    @ViewBuilder
    /// A collapsed ×N row acts on every copy: unblock and select remove them
    /// all, or the release stays blocked (web `BlocklistTab` removeAll / setMany).
    private func row(_ entry: BlocklistEntry, nested: Bool, copies: [BlocklistEntry]) -> some View {
        let ids = Set(copies.map(\.id))
        let content = BlocklistRowView(entry: entry, nested: nested, dupes: copies.count, showReasons: showReasons,
                                       selecting: selecting, checked: selected.contains(entry.id),
                                       unblock: { search in Task { await unblock(copies, search: search) } })
        if selecting {
            content.contentShape(Rectangle()).onTapGesture {
                if selected.contains(entry.id) { selected.subtract(ids) } else { selected.formUnion(ids) }
            }
        } else {
            content
        }
    }

    // MARK: Actions

    private func unblock(_ entries: [BlocklistEntry], search: Bool) async {
        guard let client = model.client, !entries.isEmpty else { return }
        do {
            if entries.count == 1 {
                try await client.deleteBlocklistEntry(id: entries[0].id)
            } else {
                try await client.deleteBlocklistEntries(ids: entries.map(\.id))
            }
            if reduce { feed.remove { e in entries.contains { $0.id == e.id } } } else {
                withAnimation(ActMotion.rows) { feed.remove { e in entries.contains { $0.id == e.id } } }
            }
            if search {
                var keys = Set<String>()
                for e in entries {
                    guard let item = e.mediaItemId else { continue }
                    let key = "\(item)-\(e.editionId ?? -1)-\(e.episodeId ?? -1)"
                    guard keys.insert(key).inserted else { continue }
                    try? await client.runSearch(itemId: item, editionId: e.editionId, episodeId: e.episodeId)
                }
            }
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
            try await client.deleteBlocklistEntries(ids: recoverable.map(\.id))
            var keys = Set<String>()
            for e in recoverable {
                guard let item = e.mediaItemId else { continue }
                let key = "\(item)-\(e.editionId ?? -1)-\(e.episodeId ?? -1)"
                guard keys.insert(key).inserted else { continue }
                try? await client.runSearch(itemId: item, editionId: e.editionId, episodeId: e.episodeId)
            }
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
                    let chosen = feed.items.filter { selected.contains($0.id) }
                    Task {
                        await unblock(chosen, search: false)
                        selected = []
                    }
                },
            ])
    }
}
