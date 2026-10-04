import SwiftUI
import FusionhaKit

// The web's History tab (`routes/activity/HistoryTab.tsx` + `activity-format.ts`):
// insight card, story/raw filter chips, Stories | Raw log, the story timeline and
// the Regrab / Blocklist / Search again actions.

// MARK: - Stories (buildHistoryStories)

fileprivate enum HistoryStoryType: String, CaseIterable {
    case upgraded, added, grabbed, failed, deleted, other

    var label: String {
        switch self {
        case .upgraded: return "Upgraded"
        case .added: return "Added"
        case .grabbed: return "Grabbed"
        case .failed: return "Failed"
        case .deleted: return "Deleted"
        case .other: return "Updated"
        }
    }

    var color: Color {
        switch self {
        case .upgraded: return Theme.edition
        case .added: return Theme.done
        case .grabbed: return Theme.grab
        case .failed: return Theme.danger
        case .deleted: return Theme.miss
        case .other: return Theme.mut
        }
    }

    var wash: Color? {
        switch self {
        case .grabbed, .upgraded: return Theme.done
        case .added: return Theme.grab
        case .deleted, .failed: return Theme.danger
        case .other: return nil
        }
    }

    var icon: String {
        switch self {
        case .upgraded: return "arrow.up"
        case .added: return "checkmark"
        case .grabbed: return "arrow.down"
        case .failed: return "xmark"
        case .deleted: return "trash"
        case .other: return "pencil"
        }
    }

    /// historyStoryActions: open / search / blocklist.
    var actions: (open: Bool, search: Bool, blocklist: Bool) {
        switch self {
        case .upgraded, .added, .grabbed: return (true, false, true)
        case .failed: return (false, true, true)
        case .deleted: return (false, true, false)
        case .other: return (true, false, false)
        }
    }
}

fileprivate struct HistoryStory: Identifiable {
    let key: String
    let type: HistoryStoryType
    let time: String
    let mediaItemId: Int?
    let title: String
    let episodeLabel: String?
    let tier: QualityTier?
    let posterUrl: String?
    let oldQuality: String?
    let oldCf: Int?
    let newQuality: String?
    let newSize: Double?
    let newCf: Int?
    let indexer: String?
    let downloadClient: String?
    let failReason: String?
    let releaseTitle: String?
    let chips: [HistoryChip]
    let actionEntry: HistoryEntry
    let events: [HistoryEntry]
    var id: String { key }
}

fileprivate enum HistoryLogic {
    struct Parsed { let title: String; let seasonEpisode: String?; let episodeName: String? }

    private static let tech = try! NSRegularExpression(
        pattern: #"\b(?:19\d\d|20\d\d|\d{3,4}p|web[ .-]?dl|web[ .-]?rip|webrip|web|blu[ .-]?ray|bdrip|brrip|dvdrip|hdtv|remux|hybrid|x26[45]|h[ .]?26[45]|hevc|avc|hdr10\+?|hdr|dovi|dv|dts(?:[ .-]?hd)?|truehd|atmos|ddp?[0-9]?|dd\+?|eac3|aac|flac|opus|proper|repack|uhd|amzn|nf|dsnp|hmax|atvp|internal|limited|extended|remastered|imax)\b"#,
        options: [.caseInsensitive])
    private static let se = try! NSRegularExpression(pattern: #"\bS(\d{1,2})(?:E(\d{1,3})(?:[-–E]E?(\d{1,3}))?)?\b"#, options: [.caseInsensitive])

    private static func clean(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "[._]+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[\[\](){}]"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"^[\s-]+|[\s-]+$"#, with: "", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    private static func techIndex(_ s: String) -> String.Index? {
        let ns = s as NSString
        guard let m = tech.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return Range(m.range, in: s)?.lowerBound
    }

    static func parse(_ raw: String?) -> Parsed {
        let source = (raw ?? "").trimmingCharacters(in: .whitespaces)
        guard !source.isEmpty else { return Parsed(title: "", seasonEpisode: nil, episodeName: nil) }
        let base = source.replacingOccurrences(of: #"\.(mkv|mp4|avi|m4v|ts|mov|wmv)$"#, with: "", options: [.regularExpression, .caseInsensitive])
        let ns = base as NSString
        if let m = se.firstMatch(in: base, range: NSRange(location: 0, length: ns.length)), let r = Range(m.range, in: base) {
            let titleFragment = String(base[..<r.lowerBound])
            let titleCut = techIndex(titleFragment).map { String(titleFragment[..<$0]) } ?? titleFragment
            let rest = String(base[r.upperBound...])
            let epFragment = techIndex(rest).map { String(rest[..<$0]) } ?? rest
            let title = clean(titleCut)
            let name = clean(epFragment)
            return Parsed(title: title.isEmpty ? clean(base) : title,
                          seasonEpisode: String(base[r]).uppercased().replacingOccurrences(of: " ", with: ""),
                          episodeName: name.isEmpty ? nil : name)
        }
        let cut = techIndex(base).map { String(base[..<$0]) } ?? base
        let title = clean(cut)
        return Parsed(title: title.isEmpty ? clean(base) : title, seasonEpisode: nil, episodeName: nil)
    }

    private static func episodeLabel(_ sources: String?...) -> String? {
        var fallback: String?
        for s in sources {
            let p = parse(s)
            guard let se = p.seasonEpisode else { continue }
            if let name = p.episodeName { return "\(se) · \(name)" }
            if fallback == nil { fallback = se }
        }
        return fallback
    }

    private static func leadTitle(_ e: HistoryEntry) -> String {
        if let t = e.itemTitle { return t }
        let p = parse(e.sourceTitle).title
        return p.isEmpty ? "Unknown" : p
    }

    static func failureReason(_ e: HistoryEntry) -> String? {
        guard e.eventType == "GRAB_FAILED" || e.eventType == "DOWNLOAD_FAILED" else { return nil }
        guard let err = e.data?.text("error"), !err.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return err
    }

    static func build(_ entries: [HistoryEntry]) -> [HistoryStory] {
        let grabs = entries.filter { $0.eventType == "GRABBED" }
        let deletes = entries.filter { $0.eventType == "DELETED" }
        let imports = entries.filter { $0.eventType == "IMPORTED" }
        let fails = entries.filter { ["GRAB_FAILED", "DOWNLOAD_FAILED", "FILE_MOVE_FAILED"].contains($0.eventType) }
        let others = entries.filter { ["RENAMED", "FILE_MOVED", "NEEDS_ATTENTION", "RENUMBERED"].contains($0.eventType) }
        var usedGrab = Set<Int>(), usedDel = Set<Int>()
        var stories: [HistoryStory] = []

        func story(_ key: String, _ type: HistoryStoryType, _ e: HistoryEntry, lead: HistoryEntry? = nil,
                   events: [HistoryEntry], old: HistoryEntry? = nil, grab: HistoryEntry? = nil) -> HistoryStory {
            HistoryStory(
                key: key, type: type, time: (lead ?? e).createdAt, mediaItemId: e.mediaItemId, title: leadTitle(e),
                episodeLabel: episodeLabel(old?.sourceTitle, e.sourceTitle, grab?.sourceTitle),
                tier: e.tier ?? grab?.tier ?? old?.tier, posterUrl: e.posterUrl ?? grab?.posterUrl ?? old?.posterUrl,
                oldQuality: old?.quality, oldCf: old?.cfScore,
                newQuality: type == .deleted ? nil : (e.quality ?? grab?.quality),
                newSize: type == .deleted ? nil : (grab?.size ?? (type == .added || type == .upgraded ? nil : e.size)),
                newCf: type == .deleted ? nil : (e.cfScore ?? grab?.cfScore),
                indexer: grab?.indexer ?? (type == .added || type == .upgraded ? nil : e.indexer),
                downloadClient: grab?.downloadClient ?? e.downloadClient,
                failReason: type == .failed ? failureReason(e) : nil,
                releaseTitle: grab?.sourceTitle ?? e.sourceTitle,
                chips: grab?.chips ?? e.chips ?? [], actionEntry: grab ?? e, events: events)
        }

        for imp in imports {
            var grab: HistoryEntry?
            var del: HistoryEntry?
            if let d = imp.downloadId {
                grab = grabs.first { $0.downloadId == d && $0.episodeId == imp.episodeId } ?? grabs.first { $0.downloadId == d && $0.episodeId == nil }
                del = deletes.first { $0.downloadId == d && $0.episodeId == imp.episodeId }
            }
            if let grab { usedGrab.insert(grab.id) }
            if let del { usedDel.insert(del.id) }
            let events = [del, imp, grab].compactMap { $0 }.sorted { (ActFmt.date($0.createdAt) ?? .distantPast) > (ActFmt.date($1.createdAt) ?? .distantPast) }
            stories.append(story("imp:\(imp.id)", del != nil ? .upgraded : .added, imp, lead: events.first, events: events, old: del, grab: grab))
        }
        for del in deletes where !usedDel.contains(del.id) {
            var s = story("del:\(del.id)", .deleted, del, events: [del])
            s = HistoryStory(key: s.key, type: s.type, time: s.time, mediaItemId: s.mediaItemId, title: s.title, episodeLabel: s.episodeLabel,
                             tier: s.tier, posterUrl: s.posterUrl, oldQuality: del.quality, oldCf: del.cfScore, newQuality: nil, newSize: nil,
                             newCf: nil, indexer: nil, downloadClient: nil, failReason: nil, releaseTitle: del.sourceTitle,
                             chips: del.chips ?? [], actionEntry: del, events: [del])
            stories.append(s)
        }
        for grab in grabs where !usedGrab.contains(grab.id) {
            stories.append(story("grab:\(grab.id)", .grabbed, grab, events: [grab], grab: grab))
        }
        for fail in fails { stories.append(story("fail:\(fail.id)", .failed, fail, events: [fail])) }
        for other in others { stories.append(story("other:\(other.id)", .other, other, events: [other])) }
        return stories.sorted { (ActFmt.date($0.time) ?? .distantPast) > (ActFmt.date($1.time) ?? .distantPast) }
    }

    /// historyFilterId for the raw log.
    static func rawFilter(_ type: String) -> String {
        switch type {
        case "GRABBED": return "grabbed"
        case "IMPORTED": return "imported"
        case "GRAB_FAILED", "DOWNLOAD_FAILED", "FILE_MOVE_FAILED": return "failed"
        case "DELETED": return "deleted"
        case "RENAMED", "FILE_MOVED": return "renamed"
        default: return "grabbed"
        }
    }

    static func eventMeta(_ type: String) -> (label: String, color: Color) {
        switch type {
        case "GRABBED": return ("Grabbed", Theme.grab)
        case "IMPORTED": return ("Imported", Theme.done)
        case "GRAB_FAILED": return ("Grab failed", Theme.danger)
        case "DOWNLOAD_FAILED": return ("Download failed", Theme.danger)
        case "DELETED": return ("Deleted", Theme.miss)
        case "RENAMED": return ("Renamed", Theme.edition)
        case "FILE_MOVED": return ("Moved", Theme.edition)
        case "FILE_MOVE_FAILED": return ("Move failed", Theme.danger)
        case "NEEDS_ATTENTION": return ("Needs attention", Theme.miss)
        case "RENUMBERED": return ("Numbering fixed", Theme.edition)
        case "RETARGETED": return ("Moved to edition", Theme.edition)
        default: return (type.replacingOccurrences(of: "_", with: " ").capitalized, Theme.mut)
        }
    }

    static func cfText(_ newCf: Int?, _ oldCf: Int?) -> String? {
        guard let newCf else { return nil }
        guard let oldCf else { return "CF \(newCf.formatted())" }
        let delta = newCf - oldCf
        return "custom-format \(newCf.formatted()) (\(delta >= 0 ? "+" : "")\(delta.formatted()))"
    }
}

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

    var body: some View {
        Group {
            if !feed.loaded && feed.error == nil {
                ActEmpty(message: "Loading history…")
            } else if feed.error != nil && feed.items.isEmpty {
                ActEmpty(message: "History could not be loaded. Check the backend and try again.")
            } else if feed.items.isEmpty {
                ActEmpty(message: search.isEmpty ? "No history yet. Grabs, imports, upgrades and failures show up here."
                                                 : "No history matches “\(search)”.")
            } else {
                loadedView
            }
        }
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
    }

    private var stories: [HistoryStory] { HistoryLogic.build(feed.items) }

    @ViewBuilder
    private var loadedView: some View {
        let stories = self.stories
        VStack(alignment: .leading, spacing: 0) {
            if raw { rawOverview.padding(.bottom, 14) } else { insight(stories).padding(.bottom, 14) }
            filterBar(stories).padding(.bottom, 12)
            if raw {
                rawLog
            } else {
                let shown = storyFilter.map { f in stories.filter { $0.type == f } } ?? stories
                if shown.isEmpty {
                    ActEmpty(message: "No \(storyFilter.map { $0.label + " " } ?? "")stories in the loaded rows\(feed.hasMore ? " yet — load more below." : ".")")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { index, story in
                            HistoryStoryRow(story: story, onChanged: { Task { await feed.refreshLoaded() } })
                                .actReveal(index)
                                .actRowTransition(reduce)
                        }
                    }
                    .padding(.leading, 26)
                    .background(alignment: .leading) {
                        Rectangle().fill(Theme.line).frame(width: 2).padding(.leading, 10).padding(.vertical, 12)
                    }
                    .animation(reduce ? nil : ActMotion.rows, value: shown.map(\.id))
                }
            }
            ActFooter(total: feed.total, loaded: feed.items.count, hasMore: feed.hasMore, loading: feed.loadingMore,
                      noun: "events", query: search) { Task { await feed.loadMore() } }
        }
    }

    // MARK: Insight card

    private func insight(_ stories: [HistoryStory]) -> some View {
        let counts = Dictionary(grouping: stories, by: \.type).mapValues(\.count)
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
        let counts = Dictionary(grouping: feed.items) { HistoryLogic.rawFilter($0.eventType) }.mapValues(\.count)
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
                    let counts = Dictionary(grouping: feed.items) { HistoryLogic.rawFilter($0.eventType) }.mapValues(\.count)
                    ActChip(label: "All", count: feed.items.count, accent: Theme.grab, selected: rawFilter == nil) { rawFilter = nil }
                    ForEach([("grabbed", "Grabbed", Theme.grab), ("imported", "Imported", Theme.done), ("failed", "Failed", Theme.danger),
                             ("deleted", "Deleted", Theme.miss), ("renamed", "Renamed", Theme.edition)], id: \.0) { id, label, color in
                        if (counts[id] ?? 0) > 0 {
                            ActChip(label: label, count: counts[id], accent: color, selected: rawFilter == id) { rawFilter = id }
                        }
                    }
                } else {
                    let counts = Dictionary(grouping: stories, by: \.type).mapValues(\.count)
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
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                if index > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
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
            }
        }
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }
}

/// One spark bar that grows in on appear (Reveal).
private struct SparkBar: View {
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

// MARK: - Story row

private struct HistoryStoryRow: View {
    let story: HistoryStory
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @State private var blocklistDialog = false
    @State private var regrabConflict = false
    @State private var regrabbing = false
    @State private var blocking = false

    var body: some View {
        let multi = story.events.count > 1 || story.failReason != nil
        ZStack(alignment: .topLeading) {
            if multi {
                ActGroupCard(wash: story.type.wash, base: Theme.card, defaultOpen: false) {
                    ActPoster(url: story.posterUrl, title: story.title, size: .md)
                } title: { lines } trailing: { trailing } content: { disclosure }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 11) {
                        ActPoster(url: story.posterUrl, title: story.title, size: .md)
                        lines.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 10) { Spacer(minLength: 0); trailing }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .actWash(story.type.wash)
            }
            // Timeline node.
            Circle()
                .fill(Theme.bg)
                .overlay(Circle().fill(story.type.color.opacity(0.24)))
                .overlay(Image(systemName: story.type.icon).font(.system(size: 10, weight: .bold)).foregroundStyle(story.type.color))
                .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
                .frame(width: 22, height: 22)
                .offset(x: -26, y: 14)
        }
        .contentShape(Rectangle())
        .onTapGesture { if let id = story.mediaItemId { model.open(id) } }
        .sheet(isPresented: $blocklistDialog) {
            BlocklistReleaseDialog(release: story.releaseTitle ?? story.title) { search, deleteFile in
                blocklistDialog = false
                Task { await blocklist(search: search, deleteFile: deleteFile, undo: false) }
            } onCancel: { blocklistDialog = false }
        }
        .sheet(isPresented: $regrabConflict) {
            ActDialog(title: "Re-grab a blocklisted release?",
                      message: "\(story.releaseTitle ?? story.title) is blocklisted for this edition. Re-grab it anyway? This clears the block first.",
                      confirmLabel: "Re-grab anyway", confirmKind: .primary, busy: regrabbing,
                      onCancel: { regrabConflict = false },
                      onConfirm: { Task { await regrab(override: true) } }) { EmptyView() }
        }
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActFlow(spacing: 6, lineSpacing: 4) {
                Text(story.type.label).font(.system(size: 14, weight: .bold)).foregroundStyle(story.type.color)
                Text(story.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                if let ep = story.episodeLabel {
                    Text(ep).font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(1)
                }
                if let tier = story.tier { ActTierChip(tier: tier, big: true) }
                if let trigger = story.actionEntry.grabTrigger { ActProvenance(trigger: trigger) }
            }
            line2
            chipRow
        }
    }

    @ViewBuilder
    private var line2: some View {
        ActFlow(spacing: 6, lineSpacing: 4) {
            if story.type == .upgraded, let old = story.oldQuality, let new = story.newQuality {
                Text(ActFmt.quality(old)).strikethrough().font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
                Text("→").font(.system(size: 11)).foregroundStyle(Theme.dim)
                Text(ActFmt.quality(new)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.txt)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.edition.opacity(0.6)))
            } else if let q = story.newQuality ?? story.oldQuality {
                Text(ActFmt.quality(q) + (story.newSize.map { " · \(ActFmt.bytes($0))" } ?? ""))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
            }
            if let cf = HistoryLogic.cfText(story.newCf, story.type == .upgraded ? story.oldCf : nil) {
                Text(cf).font(.system(size: 11.5, weight: .bold, design: .monospaced)).foregroundStyle(Theme.done)
            }
            if let client = story.downloadClient {
                Text("· \(client)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
            }
        }
        if story.type == .failed {
            let reason = story.failReason ?? story.actionEntry.data?.text("reason")
            if let reason {
                Text(reason).font(.system(size: 12.5)).foregroundStyle(Theme.danger)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var chipRow: some View {
        let order = ["group", "edition", "source", "range", "audio", "size"]
        let sorted = story.chips.sorted { (order.firstIndex(of: $0.kind) ?? 99) < (order.firstIndex(of: $1.kind) ?? 99) }
        return ActFlow(spacing: 5, lineSpacing: 5) {
            ForEach(Array(sorted.enumerated()), id: \.offset) { _, chip in
                ActMonoChip(text: chip.label, color: chipColor(chip), border: chip.kind == "group" ? Theme.indigo.opacity(0.5) : Theme.line)
            }
            if let indexer = story.indexer {
                ActMonoChip(text: indexer, color: Theme.grab, icon: "server.rack")
            }
            if let proto = ActFmt.protocolLabel(story.actionEntry.protocol) {
                ActMonoChip(text: proto, color: Theme.mut, icon: proto == "Torrent" ? "arrow.triangle.branch" : "cloud")
            }
        }
    }

    private func chipColor(_ chip: HistoryChip) -> Color {
        switch chip.kind {
        case "group": return Theme.txt
        case "range": return Color(hex: 0xFACC15)
        case "audio": return chip.label.lowercased().contains("atmos") || chip.label.lowercased().contains("dts-x") ? Color(hex: 0xF0ABFC) : Theme.mut
        default: return Theme.mut
        }
    }

    private var trailing: some View {
        let actions = story.type.actions
        let entry = story.actionEntry
        let hasGrab = story.events.contains { $0.eventType == "GRABBED" }
        return HStack(spacing: 2) {
            Text(ActFmt.relative(story.time)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim).padding(.trailing, 6)
            if hasGrab {
                ActIconButton(systemImage: "arrow.clockwise", label: "Re-grab this release", busy: regrabbing) {
                    Task { await regrab(override: false) }
                }
            }
            if actions.blocklist {
                // The split button: quick blocklist + search (with Undo), caret opens the dialog.
                HStack(spacing: 0) {
                    ActIconButton(systemImage: "nosign", label: "Blocklist this release", busy: blocking) {
                        Task { await blocklist(search: true, deleteFile: false, undo: true) }
                    }
                    .padding(.trailing, -10)
                    Button { blocklistDialog = true } label: {
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.dim)
                            .frame(width: 18, height: 40).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Blocklist options")
                }
            }
            if actions.search {
                ActIconButton(systemImage: "magnifyingglass", label: "Search again", tint: Theme.indigo) { searchAgain() }
            } else if actions.open, let id = story.mediaItemId {
                ActIconButton(systemImage: "arrow.up.right.square", label: "Open in library") { model.open(id) }
            }
            ActMoreMenu {
                if actions.search {
                    if let id = story.mediaItemId { Button("Open in library", systemImage: "arrow.up.right.square") { model.open(id) } }
                } else {
                    Button("Search again", systemImage: "magnifyingglass") { searchAgain() }
                }
                if let id = story.mediaItemId {
                    Button("Why this decision", systemImage: "list.bullet") { model.open(id) }
                }
                Button("Copy release name", systemImage: "doc.on.doc") { ActActions.copy(entry.sourceTitle ?? story.releaseTitle, toaster) }
            }
            .padding(.horizontal, -6)
        }
    }

    @ViewBuilder
    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            if story.events.count > 1 {
                ForEach(story.events) { event in
                    let meta = HistoryLogic.eventMeta(event.eventType)
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(meta.color).frame(width: 7, height: 7).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meta.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(meta.color)
                            if let src = event.sourceTitle {
                                Text(src).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                            }
                        }
                        Spacer(minLength: 0)
                        Text(ActFmt.relative(event.createdAt)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                    }
                }
            } else {
                if let release = story.releaseTitle {
                    Text(release).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim)
                }
                if let reason = story.failReason {
                    Text("\(story.title) — \(reason)").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    Text("RAW REASON").font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(Theme.dim)
                    Text(reason).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Actions

    private func searchAgain() {
        guard let id = story.mediaItemId else { return }
        Task { await ActActions.search(model.client, toaster, itemId: id, editionId: story.actionEntry.editionId,
                                       message: "Searching again for \(story.title)") }
    }

    private func blocklist(search: Bool, deleteFile: Bool, undo: Bool) async {
        blocking = true
        await ActActions.blocklist(model.client, toaster,
                                   BlocklistCreate(historyId: story.actionEntry.id, search: search, deleteCurrentFile: deleteFile),
                                   offerUndo: undo, done: onChanged)
        blocking = false
    }

    private func regrab(override: Bool) async {
        guard let client = model.client else { return }
        regrabbing = true
        defer { regrabbing = false }
        do {
            let r = try await client.regrab(historyId: story.actionEntry.id, override: override)
            regrabConflict = false
            if r.grabbed {
                let indexer = r.indexerName ?? "the indexer"
                toaster.show(r.fromOriginalIndexer == false ? "Grabbed from \(indexer) (original unavailable)" : "Re-grabbed from \(indexer)",
                             tone: .success)
                onChanged()
            } else {
                toaster.show(r.reason ?? "Nothing to re-grab", tone: .warning)
            }
        } catch let error as APIError where error.status == 409 && !override {
            regrabConflict = true
        } catch let error as APIError where error.status == 422 || error.status == 404 {
            toaster.show(error.serverMessage ?? "Couldn't re-grab this release — try again", tone: .warning)
        } catch {
            toaster.show("Couldn't re-grab this release — try again", tone: .error)
        }
    }
}

/// The caret's "Blocklist this release?" dialog.
private struct BlocklistReleaseDialog: View {
    let release: String
    let onConfirm: (_ search: Bool, _ deleteFile: Bool) -> Void
    let onCancel: () -> Void
    @State private var search = true
    @State private var deleteFile = false

    private var confirmLabel: String {
        switch (deleteFile, search) {
        case (false, false): return "Blocklist"
        case (false, true): return "Blocklist and search"
        case (true, false): return "Blocklist & delete"
        case (true, true): return "Blocklist, delete & search"
        }
    }

    var body: some View {
        ActDialog(title: "Blocklist this release?",
                  message: "\(release) will never be grabbed again for this edition.",
                  confirmLabel: confirmLabel, onCancel: onCancel, onConfirm: { onConfirm(search, deleteFile) }) {
            ActOption(label: "Also search for a replacement", isOn: $search)
            ActOption(label: "Delete the current file",
                      hint: "Needed to replace a file that already scores well — a search alone won’t beat it.",
                      isOn: $deleteFile)
        }
    }
}

// Compact history row, used by the item detail screen's history section.
struct HistoryRow: View {
    let entry: HistoryEntry

    private var color: Color {
        let type = entry.eventType.uppercased()
        if type.contains("FAIL") || type.contains("DELETE") || type.contains("REJECT") { return Theme.danger }
        if type.contains("IMPORT") || type.contains("DOWNLOADED") { return Theme.done }
        if type.contains("GRAB") { return Theme.grab }
        if type.contains("UPGRADE") { return Theme.edition }
        return Theme.mut
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(url: TMDBImage.resized(entry.posterUrl, to: "w154"))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.itemTitle ?? "Unknown title")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if let tier = entry.tier { TierPill(tier: tier) }
                    Spacer(minLength: 0)
                    Text(Format.relative(entry.createdAt))
                        .font(.system(size: 11)).foregroundStyle(Theme.dim).lineLimit(1)
                }
                Text(entry.eventLabel)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(color)
                if let source = entry.sourceTitle {
                    Text(source)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(2)
                }
                if let chips = entry.chips, !chips.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.mut)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 5))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))
                        }
                    }
                }
            }
        }
        .padding(12)
        .panel(Theme.card, radius: 14)
        .contentShape(Rectangle())
    }
}

