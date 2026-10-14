import SwiftUI
import FusionhaKit

// The web's History tab (`routes/activity/HistoryTab.tsx` + `activity-format.ts`):
// insight card, story/raw filter chips, Stories | Raw log, the story timeline and
// the Regrab / Blocklist / Search again actions.

// MARK: - Tab

struct ActivityHistoryTab: View {
    let search: String
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var feed = ActFeed<HistoryEntry> { _, _ in ([], 0) }
    @State private var sparkline: [HistorySparklineDay] = []
    @State private var raw = false
    @State private var storyFilter: HistoryStoryType?
    @State private var rawFilter: String?
    @State private var derived = HistoryDerived()

    var body: some View {
        let _ = PerfCount.hit("ActivityHistoryTab.body")
        ActivityPage {
            if (!feed.loaded && feed.error == nil) || (derived.revision < 0 && !feed.items.isEmpty) {
                ActEmpty(message: "Loading history…")
            } else if feed.error != nil && feed.items.isEmpty {
                ActEmpty(message: "History could not be loaded. Check the backend and try again.")
            } else if feed.items.isEmpty {
                ActEmpty(message: search.isEmpty ? "No history yet. Grabs, imports, upgrades and failures show up here."
                                                 : "No history matches “\(search)”.")
            } else {
                loadedRows
            }
        }
        // Filter switches animate; page appends don't (animating a whole page's
        // insertion made the lazy stack build every new row at once).
        .animation(reduce ? nil : ActMotion.rows, value: RowsKey(filter: storyFilter, raw: raw))
        .task(id: search) {
            let client = model.client
            let q = search
            feed.fetch = { page, size in
                guard let client else { return ([], 0) }
                let r = try await client.historyPage(page: page, pageSize: size, query: q)
                return (r.items, r.total)
            }
            await feed.reload(resetting: true)
            if let days = try? await client?.historySparkline(days: 14) { sparkline = days }
        }
        .task(id: feed.revision) { await rebuild() }
    }

    private struct RowsKey: Equatable {
        let filter: HistoryStoryType?
        let raw: Bool
    }

    /// Stories, counts and filters are derived once per feed change, off the main actor.
    private func rebuild() async {
        let items = feed.items
        let revision = feed.revision
        let next = await Task.detached(priority: .userInitiated) {
            PerfCount.time("HistoryLogic.build") { HistoryDerived.make(items, revision: revision) }
        }.value
        guard !Task.isCancelled, revision == feed.revision else { return }
        derived = next
    }

    /// Flat children of the page's lazy stack: overview, filters, one child per row, footer.
    @ViewBuilder
    private var loadedRows: some View {
        let stories = derived.stories
        if raw { rawOverview.padding(.bottom, 14) } else { insight(stories).padding(.bottom, 14) }
        filterBar(stories).padding(.bottom, 12)
        if raw {
            rawLog
        } else {
            let shown = storyFilter.map { f in stories.filter { $0.type == f } } ?? stories
            if shown.isEmpty {
                ActEmpty(message: "No \(storyFilter.map { $0.label + " " } ?? "")stories in the loaded rows\(feed.hasMore ? " yet — load more below." : ".")")
            } else {
                let last = shown.count - 1
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, story in
                    HistoryStoryRow(story: story, onChanged: { Task { await feed.refreshLoaded() } })
                        .actReveal(index)
                        .padding(.leading, 26)
                        .padding(.bottom, index == last ? 0 : 10)
                        .background(alignment: .leading) { ActTimelineSegment(first: index == 0, last: index == last) }
                        .actRowTransition(reduce)
                }
            }
        }
        ActFooter(total: feed.total, loaded: feed.items.count, hasMore: feed.hasMore, loading: feed.loadingMore,
                  noun: "events", query: search) { Task { await feed.loadMore() } }
    }

    // MARK: Insight card

    private func insight(_ stories: [HistoryStory]) -> some View {
        let counts = derived.storyCounts
        let maxCount = max(sparkline.map(\.count).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(feed.total)").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.txt)
                        .contentTransition(.numericText(value: Double(feed.total)))
                    Text("EVENTS").font(.system(size: 11)).tracking(0.6).foregroundStyle(Theme.dim)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(sparkline.enumerated()), id: \.offset) { index, day in
                        SparkBar(fraction: Double(day.count) / Double(maxCount), hot: Double(day.count) >= 0.75 * Double(maxCount) && day.count > 0,
                                 index: index)
                    }
                }
                .frame(height: 42, alignment: .bottom)
            }
            ActFlow(spacing: 14, lineSpacing: 8) {
                kpi(counts[.upgraded] ?? 0, "upgraded", Theme.edition)
                kpi(counts[.added] ?? 0, "added", Theme.done)
                kpi(counts[.failed] ?? 0, "failed", Theme.danger)
                kpi(counts[.grabbed] ?? 0, "grabbed", Theme.grab)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func kpi(_ value: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text("\(value)").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
    }

    private var rawOverview: some View {
        let counts = derived.rawCounts
        return ActOverview(total: feed.total, label: "events", stats: [
            .init(label: "Grabbed", value: counts["grabbed"] ?? 0, color: Theme.grab),
            .init(label: "Imported", value: counts["imported"] ?? 0, color: Theme.done),
            .init(label: "Failed", value: counts["failed"] ?? 0, color: Theme.danger),
            .init(label: "Deleted", value: counts["deleted"] ?? 0, color: Theme.miss),
        ])
    }

    // MARK: Filters

    private func filterBar(_ stories: [HistoryStory]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ActFlow(spacing: 8, lineSpacing: 8) {
                if raw {
                    let counts = derived.rawCounts
                    ActChip(label: "All", count: feed.items.count, accent: Theme.grab, selected: rawFilter == nil) { rawFilter = nil }
                    ForEach([("grabbed", "Grabbed", Theme.grab), ("imported", "Imported", Theme.done), ("failed", "Failed", Theme.danger),
                             ("deleted", "Deleted", Theme.miss), ("renamed", "Renamed", Theme.edition)], id: \.0) { id, label, color in
                        if (counts[id] ?? 0) > 0 {
                            ActChip(label: label, count: counts[id], accent: color, selected: rawFilter == id) { rawFilter = id }
                        }
                    }
                } else {
                    let counts = derived.storyCounts
                    ActChip(label: "All", count: stories.count, accent: Theme.grab, selected: storyFilter == nil) { storyFilter = nil }
                    ForEach([HistoryStoryType.upgraded, .added, .failed, .deleted], id: \.self) { type in
                        if (counts[type] ?? 0) > 0 {
                            ActChip(label: type == .upgraded ? "Upgrades" : type.label, count: counts[type], accent: type.color,
                                    selected: storyFilter == type) { storyFilter = type }
                        }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                ActSegment(options: [(false, "Stories"), (true, "Raw log")], selection: $raw)
            }
        }
    }

    // MARK: Raw log

    @ViewBuilder
    private var rawLog: some View {
        let rows = rawFilter.map { f in feed.items.filter { HistoryLogic.rawFilter($0.eventType) == f } } ?? feed.items
        let last = rows.count - 1
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
            let meta = HistoryLogic.eventMeta(entry.eventType)
            VStack(alignment: .leading, spacing: 4) {
                ActFlow(spacing: 6, lineSpacing: 3) {
                    Text(ActFmt.relative(entry.createdAt)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                    Text(meta.label).font(.system(size: 11, weight: .bold)).foregroundStyle(meta.color)
                    if let trigger = entry.grabTrigger { ActProvenance(trigger: trigger) }
                    Text(entry.itemTitle ?? "Unknown").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                }
                ActFlow(spacing: 6, lineSpacing: 3) {
                    if let src = entry.sourceTitle {
                        Text(src).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.mut).lineLimit(1).truncationMode(.middle)
                    }
                    if let q = entry.quality { ActQualityChip(quality: q) }
                    if let size = entry.size { Text(ActFmt.bytes(size)).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.dim) }
                    if let cf = entry.cfScore { Text("CF \(cf)").font(.system(size: 10.5, weight: .bold, design: .monospaced)).foregroundStyle(Theme.done) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { if let id = entry.mediaItemId { model.open(id) } }
            .actReveal(index, stagger: 0.02)
            .actCardSegment(first: index == 0, last: index == last)
        }
    }
}

/// One spark bar that grows in on appear (Reveal).
struct SparkBar: View {
    let fraction: Double
    let hot: Bool
    let index: Int
    @Environment(\.actReduceMotion) private var reduce
    @State private var grown = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(hot ? AnyShapeStyle(Theme.grab) : AnyShapeStyle(LinearGradient(colors: [Theme.edition, Theme.edition.opacity(0.45)], startPoint: .top, endPoint: .bottom)))
            .frame(width: 7, height: max(2, 42 * (reduce || grown ? fraction : 0)))
            .onAppear {
                guard !reduce else { return }
                withAnimation(ActMotion.reveal(0.6).delay(Double(index) * 0.03)) { grown = true }
            }
    }
}
