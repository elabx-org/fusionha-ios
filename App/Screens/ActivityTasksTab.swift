import SwiftUI
import FusionhaKit

// Activity · Tasks (`routes/TasksTab.tsx`, `TasksTab.module.css`,
// `routes/tasks-format.ts`): the voice toggle, the System cards (Media
// enrichment / RSS Sync / Scheduled), live backlog searches with Stop, Scanning
// and Queued runs, and the Recent timeline with each run's decision trail.

// MARK: - Logic (tasks-format.ts)

fileprivate enum TaskIconKind { case search, rss, refresh, fail }

fileprivate struct FactPart: Hashable {
    enum Tone { case grab, up, miss }
    let text: String
    var tone: Tone?
}

fileprivate enum TasksLogic {
    static func iconKind(_ run: CommandRun) -> TaskIconKind {
        if run.status == "failed" { return .fail }
        if run.trigger == "rss" { return .rss }
        if run.trigger == "scheduled" { return .refresh }
        return .search
    }

    static func isStuckNoGrab(_ run: CommandRun) -> Bool {
        run.status == "completed" && run.releases > 0 && run.grabbed == 0 && run.upgraded == 0
    }

    static func factParts(_ run: CommandRun) -> [FactPart] {
        if run.status == "failed" {
            var parts = [FactPart(text: "Failed", tone: .miss)]
            if run.errors > 0 { parts.append(FactPart(text: ActFmt.plural(run.errors, "error"))) }
            return parts
        }
        if run.status == "running", let phase = run.phase, !phase.isEmpty {
            let label = phase.prefix(1).uppercased() + phase.dropFirst()
            let total = run.progressTotal ?? 0
            return [FactPart(text: total > 0 ? "\(label) \(run.progressCurrent ?? 0)/\(total)" : label)]
        }
        if run.status != "running" {
            if run.grabbed > 0 || run.upgraded > 0 {
                var parts: [FactPart] = []
                if run.grabbed > 0 { parts.append(FactPart(text: "Grabbed \(run.grabbed)", tone: .grab)) }
                if run.upgraded > 0 { parts.append(FactPart(text: "\(run.upgraded) upgraded", tone: .up)) }
                parts.append(FactPart(text: "\(run.releases) found"))
                if run.rejected > 0 { parts.append(FactPart(text: "\(run.rejected) rejected", tone: .miss)) }
                return parts
            }
            if isStuckNoGrab(run) {
                return [FactPart(text: "Nothing grabbed — \(run.releases) found, all rejected", tone: .miss)]
            }
            if run.releases == 0, run.skippedInFlight == true {
                return [FactPart(text: "Already downloading — nothing to search")]
            }
            if run.releases == 0 { return [FactPart(text: "No releases found")] }
            return [FactPart(text: "\(run.releases) found")]
        }
        var parts: [FactPart] = []
        if run.grabbed > 0 { parts.append(FactPart(text: "Grabbed \(run.grabbed)", tone: .grab)) }
        if run.upgraded > 0 { parts.append(FactPart(text: "\(run.upgraded) upgraded", tone: .up)) }
        if run.evaluated > 0 {
            parts.append(FactPart(text: run.releases > 0 ? "\(run.evaluated) / \(run.releases) evaluated" : "\(run.evaluated) evaluated"))
        } else if run.releases > 0 {
            parts.append(FactPart(text: "\(run.releases) releases"))
        }
        if parts.isEmpty { parts.append(FactPart(text: "Searching…")) }
        return parts
    }

    static func factualLine(_ run: CommandRun) -> String {
        let text = factParts(run).map(\.text).joined(separator: " · ")
        return text.isEmpty ? "Done" : text
    }

    static func progressPct(_ run: CommandRun) -> Double? {
        guard run.releases > 0 else { return nil }
        return min(1, max(0, Double(run.evaluated) / Double(run.releases)))
    }

    static func targetDetail(_ run: CommandRun) -> String? { run.targetSummary ?? run.targetTitle }

    static func targetCountLabel(_ run: CommandRun) -> String? {
        run.targetCount.map { ActFmt.plural($0, "target") }
    }

    struct RunGroup: Identifiable {
        let key: String
        let latest: CommandRun
        var older: [CommandRun]
        var id: String { key }
    }

    static func groupKey(_ run: CommandRun) -> String {
        if run.trigger == "rss" || run.trigger == "scheduled" { return "\(run.trigger)::\(run.name)" }
        return "\(run.trigger)::\(run.name)::\(run.targetTitle ?? "#\(run.id)")"
    }

    static func groupRuns(_ runs: [CommandRun]) -> [RunGroup] {
        var order: [String] = []
        var byKey: [String: RunGroup] = [:]
        for run in runs {
            let key = groupKey(run)
            if byKey[key] != nil {
                byKey[key]?.older.append(run)
            } else {
                byKey[key] = RunGroup(key: key, latest: run, older: [])
                order.append(key)
            }
        }
        return order.compactMap { byKey[$0] }
    }

    static func earlierLabel(_ group: RunGroup) -> String {
        let n = group.older.count
        return "\(n) earlier \(group.latest.name)\(n == 1 ? "" : "s")"
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func isRss(_ name: String) -> Bool { normalize(name).contains("rsssync") }
    static func isEnrichment(_ name: String) -> Bool { normalize(name).contains("enrichment") }

    static func scheduledTasks(_ tasks: [SystemTask], limit: Int = 2) -> [SystemTask] {
        tasks.filter { !isRss($0.name) && !isEnrichment($0.name) }
            .sorted { (ActFmt.date($0.nextRun) ?? .distantFuture) < (ActFmt.date($1.nextRun) ?? .distantFuture) }
            .prefix(limit)
            .map { $0 }
    }

    /// `schedulerTaskForRun`: only an unambiguous label match for a background sweep.
    static func schedulerTask(for run: CommandRun, in tasks: [SystemTask]) -> SystemTask? {
        guard run.trigger == "scheduled" || run.trigger == "rss" else { return nil }
        let wanted = run.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !wanted.isEmpty else { return nil }
        let matches = tasks.filter { ActFmt.taskLabel($0.name).lowercased() == wanted }
        return matches.count == 1 ? matches[0] : nil
    }

    // Backlog search card
    static func searchingCount(_ s: SearchProgress) -> Int { s.targets.filter { $0.state == "searching" }.count }

    static func searchPct(_ s: SearchProgress) -> Int {
        guard s.total > 0 else { return 0 }
        return min(100, max(0, Int((Double(s.processed) / Double(s.total) * 100).rounded())))
    }

    static func scopeLine(_ s: SearchProgress) -> String {
        var titles: [String] = []
        for t in s.targets where !titles.contains(t.group) { titles.append(t.group) }
        let targets = ActFmt.plural(s.total, "target")
        guard !titles.isEmpty else { return targets }
        let shown = titles.prefix(3).joined(separator: ", ")
        let extra = titles.count - 3
        return "\(targets) across \(ActFmt.plural(titles.count, "title")) · \(extra > 0 ? "\(shown) +\(extra)" : shown)"
    }

    struct ScopeGroup: Identifiable {
        let key: String
        let group: String
        let tier: String?
        var targets: [SearchScopeTarget]
        var id: String { key }
    }

    static func groupTargets(_ targets: [SearchScopeTarget]) -> [ScopeGroup] {
        var order: [String] = []
        var byKey: [String: ScopeGroup] = [:]
        for t in targets {
            let key = "\(t.group) \(t.tier ?? "")"
            if byKey[key] != nil { byKey[key]?.targets.append(t) } else {
                byKey[key] = ScopeGroup(key: key, group: t.group, tier: t.tier, targets: [t])
                order.append(key)
            }
        }
        return order.compactMap { byKey[$0] }
    }

    static func isUhd(_ tier: String?) -> Bool {
        guard let tier else { return false }
        return tier.range(of: "2160|uhd|4k", options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func duration(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return "a while" }
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s)s" }
        if s < 3600 { return s % 60 == 0 ? "\(s / 60)m" : "\(s / 60)m \(s % 60)s" }
        let m = (s % 3600) / 60
        return m > 0 ? "\(s / 3600)h \(m)m" : "\(s / 3600)h"
    }

    // Decision trail (trail-grouping.ts)
    enum BucketTone { case wrong, notbetter, skip, blocked, grab
        var color: Color {
            switch self {
            case .wrong: return Theme.miss
            case .notbetter: return Theme.stuck
            case .skip: return Theme.unmonitored
            case .blocked: return Theme.danger
            case .grab: return Theme.done
            }
        }
    }

    struct Bucket { let key: String; let label: String; let tone: BucketTone }

    static func bucket(_ c: RunCandidate) -> Bucket {
        let r = c.reason.lowercased()
        if c.blocklisted == true || r.contains("blocklist") { return Bucket(key: "blocklisted", label: "Blocklisted", tone: .blocked) }
        if r.contains("already") || r.contains("in flight") || r.contains("pre-excluded")
            || (r.contains("download for this release") && r.contains("exists")) {
            return Bucket(key: "already", label: "Already grabbed", tone: .skip)
        }
        if r.contains("download client unavailable") || r.contains("database busy") || r.hasPrefix("not grabbed") {
            return Bucket(key: "grab-failed", label: "Couldn't be grabbed", tone: .blocked)
        }
        if r.contains("not an upgrade") { return Bucket(key: "upgrade", label: "No upgrade over your file", tone: .notbetter) }
        if r.contains("not wanted in the quality profile") { return Bucket(key: "quality", label: "Not in your quality profile", tone: .wrong) }
        if r.contains("custom format score") || r.contains("profile minimum") {
            return Bucket(key: "cf-floor", label: "Below the custom-format floor", tone: .wrong)
        }
        if r.contains("rejected on size") || r.contains("size window") { return Bucket(key: "size", label: "Outside the size window", tone: .wrong) }
        if r.contains("edition") && r.contains("does not match") { return Bucket(key: "edition", label: "Wrong movie edition", tone: .wrong) }
        return Bucket(key: "other:\(r)", label: c.reason.isEmpty ? "Passed over" : c.reason, tone: .skip)
    }

    struct DedupRow: Identifiable {
        let rep: RunCandidate
        let count: Int
        let indexers: Int
        var id: Int { rep.id }
    }

    static func dedupe(_ cands: [RunCandidate]) -> [DedupRow] {
        func key(_ title: String) -> String {
            title.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        var order: [String] = []
        var members: [String: [RunCandidate]] = [:]
        for c in cands {
            let k = key(c.releaseTitle)
            if members[k] == nil { order.append(k); members[k] = [] }
            members[k]?.append(c)
        }
        return order.compactMap { k in
            guard let m = members[k], let first = m.first else { return nil }
            let rep = m.reduce(first) { ($1.cfScore ?? Int.min) > ($0.cfScore ?? Int.min) ? $1 : $0 }
            return DedupRow(rep: rep, count: m.count, indexers: Set(m.compactMap(\.indexer)).count)
        }
    }

    struct ReasonGroup: Identifiable {
        let bucket: Bucket
        let rows: [DedupRow]
        let total: Int
        let qualifier: String?
        var id: String { bucket.key }
    }

    static func groupByReason(_ cands: [RunCandidate]) -> [ReasonGroup] {
        var order: [String] = []
        var byKey: [String: (Bucket, [RunCandidate])] = [:]
        for c in cands {
            let b = bucket(c)
            if byKey[b.key] == nil { order.append(b.key); byKey[b.key] = (b, []) }
            byKey[b.key]?.1.append(c)
        }
        let groups: [ReasonGroup] = order.compactMap { k in
            guard let entry = byKey[k] else { return nil }
            return ReasonGroup(bucket: entry.0, rows: dedupe(entry.1), total: entry.1.count, qualifier: qualifier(entry.0, entry.1))
        }
        return groups.enumerated().sorted { a, b in
            a.element.total != b.element.total ? a.element.total > b.element.total : a.offset < b.offset
        }.map(\.element)
    }

    private static func qualifier(_ b: Bucket, _ members: [RunCandidate]) -> String? {
        switch b.key {
        case "quality":
            var seen: [String] = []
            for m in members { if let q = m.quality.map(ActFmt.quality), !seen.contains(q) { seen.append(q) } }
            let qs = Array(seen.prefix(4))
            guard !qs.isEmpty else { return nil }
            let phrase: String
            if qs.count == 1 { phrase = qs[0] } else if qs.count == 2 { phrase = "\(qs[0]) and \(qs[1])" } else {
                phrase = qs.dropLast().joined(separator: ", ") + " and " + (qs.last ?? "")
            }
            return "\(phrase) \(qs.count > 1 ? "aren't" : "isn't") in the ladder"
        case "upgrade":
            let reason = members.first?.reason ?? ""
            if let range = reason.range(of: "existing (.+?) file", options: [.regularExpression, .caseInsensitive]) {
                let match = String(reason[range])
                let inner = match.dropFirst("existing ".count).dropLast(" file".count)
                return "current file: \(inner)"
            }
            return nil
        case "already":
            return "a download for this release already exists"
        default:
            return nil
        }
    }
}

// MARK: - Store

@MainActor
@Observable
fileprivate final class TasksStore {
    let feed = ActFeed<CommandRun>(pageSize: 200) { _, _ in ([], 0) }
    var tasks: [SystemTask] = []
    var enrichment: EnrichmentStatus?
    var playful = true

    var anyRunning: Bool { feed.items.contains { $0.status == "running" } || tasks.contains { $0.running } }

    func load(_ client: APIClient?) async {
        feed.fetch = { page, size in
            guard let client else { return ([], 0) }
            let r = try await client.systemRuns(page: page, pageSize: size)
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
        async let t = try? client.systemTasks()
        async let e = try? client.enrichmentStatus()
        if let tasks = await t { self.tasks = tasks }
        enrichment = await e
    }
}

// MARK: - Tab

struct ActivityTasksTab: View {
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var store = TasksStore()

    var body: some View {
        let feed = store.feed
        Group {
            if !feed.loaded && feed.error == nil {
                ActEmpty(message: "Loading the task feed…")
            } else if feed.error != nil && feed.items.isEmpty {
                ActEmpty(message: "The task feed could not be loaded. Check the backend and try again.")
            } else {
                loadedView
            }
        }
        .task {
            await store.load(model.client)
            // The web polls fast (2s) while any run is live, slowly otherwise.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(store.anyRunning ? 2 : 15))
                guard !Task.isCancelled else { return }
                await store.refresh(model.client)
            }
        }
    }

    @ViewBuilder
    private var loadedView: some View {
        let items = store.feed.items
        let running = items.filter { $0.status == "running" }
        let searchRuns = running.filter { $0.search != nil }
        let scanning = running.filter { $0.search == nil && $0.phase != nil && $0.phase != "queued" }
        let queued = running.filter { $0.search == nil && ($0.phase == nil || $0.phase == "queued") }
        let recent = items.filter { $0.status != "running" }
        let enrich = store.enrichment
        let showEnrichment = (enrich?.pendingFiles ?? 0) > 0 || (enrich?.issueFiles ?? 0) > 0
        let rssTask = store.tasks.first { TasksLogic.isRss($0.name) }
        let scheduled = TasksLogic.scheduledTasks(store.tasks)
        let showSystem = showEnrichment || rssTask != nil || !scheduled.isEmpty

        if running.isEmpty && recent.isEmpty && !showSystem {
            ActEmpty(message: "No searches yet. RSS syncs, scheduled sweeps and searches show up here — each with what it grabbed and why.")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                voiceToggle.padding(.bottom, 16)
                if showSystem {
                    sectionLabel("System")
                    VStack(spacing: 10) {
                        if showEnrichment, let enrich { EnrichmentCard(status: enrich) }
                        if let rssTask { RssSyncCard(task: rssTask, latestRun: items.first { $0.trigger == "rss" }) }
                        if !scheduled.isEmpty { ScheduledCard(tasks: scheduled) }
                    }
                }
                if !searchRuns.isEmpty {
                    sectionLabel("Searching").padding(.top, showSystem ? 22 : 0)
                    VStack(spacing: 9) {
                        ForEach(searchRuns) { run in
                            SearchRunCard(run: run) { Task { await store.refresh(model.client) } }
                                .actRowTransition(reduce)
                        }
                    }
                }
                if !scanning.isEmpty {
                    sectionLabel("Scanning").padding(.top, showSystem || !searchRuns.isEmpty ? 22 : 0)
                    VStack(spacing: 9) {
                        ForEach(scanning) { run in
                            RunningRow(run: run, queued: false, playful: store.playful).actRowTransition(reduce)
                        }
                    }
                }
                if !queued.isEmpty {
                    sectionLabel("Queued (\(queued.count))").padding(.top, !searchRuns.isEmpty || !scanning.isEmpty ? 22 : 0)
                    VStack(spacing: 9) {
                        ForEach(queued) { run in
                            RunningRow(run: run, queued: true, playful: store.playful).actRowTransition(reduce)
                        }
                    }
                }
                if !recent.isEmpty {
                    sectionLabel("Recent").padding(.top, !running.isEmpty || showSystem ? 22 : 0)
                    VStack(spacing: 9) {
                        ForEach(Array(TasksLogic.groupRuns(recent).enumerated()), id: \.element.id) { index, group in
                            RecentGroupView(group: group, tasks: store.tasks)
                                .actReveal(index, stagger: 0.03)
                        }
                    }
                    .background(alignment: .topLeading) {
                        // The timeline thread behind the trigger icons (left 32).
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: Theme.line, location: 0.06),
                                               .init(color: Theme.line, location: 0.94), .init(color: .clear, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(width: 2)
                            .padding(.vertical, 4)
                            .padding(.leading, 31)
                    }
                }
                ActFooter(total: store.feed.total, loaded: store.feed.items.count, hasMore: store.feed.hasMore,
                          loading: store.feed.loadingMore, noun: "task runs") { Task { await store.feed.loadMore() } }
            }
            .animation(reduce ? nil : ActMotion.rows, value: items.map(\.id))
            .animation(reduce ? nil : ActMotion.rows, value: running.map(\.id))
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

// MARK: - Shared pieces

/// The 36×36 r10 tinted icon tile (`.cico`).
private struct TaskIconTile: View {
    let color: Color
    var spinning = false
    var size: CGFloat = 36
    var radius: CGFloat = 10
    var glyph: CGFloat = 18
    let icon: AnyView

    init(color: Color, spinning: Bool = false, size: CGFloat = 36, radius: CGFloat = 10, glyph: CGFloat = 18, @ViewBuilder icon: () -> some View) {
        self.color = color
        self.spinning = spinning
        self.size = size
        self.radius = radius
        self.glyph = glyph
        self.icon = AnyView(icon())
    }

    var body: some View {
        icon
            .font(.system(size: glyph * 0.8, weight: .semibold))
            .frame(width: glyph, height: glyph)
            .actSpin(spinning, duration: 1.1)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// The broken-ring spinner glyph.
private struct TaskSpinnerGlyph: View {
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.8)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-20))
            .padding(1.5)
    }
}

private func taskIcon(_ kind: TaskIconKind) -> String {
    switch kind {
    case .search: return "magnifyingglass"
    case .rss: return "dot.radiowaves.up.forward"
    case .refresh: return "arrow.clockwise"
    case .fail: return "exclamationmark.circle"
    }
}

private func taskIconColor(_ kind: TaskIconKind) -> Color {
    switch kind {
    case .search: return Theme.grab
    case .rss: return Theme.edition
    case .refresh: return Theme.unaired
    case .fail: return Theme.danger
    }
}

/// The `.cmd` card frame.
private struct TaskCard: ViewModifier {
    var border: Color = Theme.line

    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(border))
    }
}

/// `TaskName`: name · target detail (N targets).
private struct TaskNameLine: View {
    let run: CommandRun

    var body: some View {
        var text = Text(run.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
        if let detail = TasksLogic.targetDetail(run) {
            text = text + Text(" · \(detail)").font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundColor(Theme.mut)
        }
        if let count = TasksLogic.targetCountLabel(run) {
            text = text + Text(" (\(count))").font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundColor(Theme.dim)
        }
        return text.lineLimit(2)
    }
}

/// `TaskLine`: the coloured fact segments joined by " · ".
private struct TaskFactLine: View {
    let run: CommandRun

    var body: some View {
        let parts = TasksLogic.factParts(run)
        var text = Text("")
        for (index, part) in parts.enumerated() {
            if index > 0 { text = text + Text(" · ") }
            if let tone = part.tone {
                let color: Color = tone == .grab ? Theme.done : (tone == .up ? Theme.grab : Theme.miss)
                text = text + Text(part.text).font(.system(size: 12.5, weight: .bold, design: .monospaced)).foregroundColor(color)
            } else {
                text = text + Text(part.text)
            }
        }
        return text
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.mut)
            .padding(.top, 3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The 5pt run bar (`.bar`): gradient fill, live sweep while indeterminate.
private struct TaskBar: View {
    let fraction: Double
    var live = false
    var done = false

    var body: some View {
        ActProgressBar(fraction: fraction, height: 5,
                       fill: done ? AnyShapeStyle(Theme.done)
                                  : AnyShapeStyle(LinearGradient(colors: [Theme.indigo, Theme.cyan], startPoint: .leading, endPoint: .trailing)),
                       shimmer: live)
            .padding(.top, 8)
    }
}

// MARK: - System cards

private struct EnrichmentCard: View {
    let status: EnrichmentStatus
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let total = max(0, status.totalFiles ?? 0)
        let enriched = min(max(0, status.enrichedFiles ?? 0), total)
        let issues = max(0, status.issueFiles ?? 0)
        let pending = max(0, status.pendingFiles ?? 0)
        let pct = total > 0 ? min(100, Int((Double(enriched) / Double(total) * 100).rounded())) : 0
        let settled = pending == 0
        HStack(alignment: .center, spacing: 13) {
            if settled {
                TaskIconTile(color: Theme.done) { Image(systemName: "checkmark").fontWeight(.heavy) }
            } else {
                TaskIconTile(color: Theme.grab, spinning: !reduce) { TaskSpinnerGlyph() }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Media enrichment").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                Group {
                    if settled {
                        (Text("Complete").foregroundColor(Theme.done).fontWeight(.semibold)
                         + Text(" · \(enriched.formatted()) of \(total.formatted()) analysed")
                         + Text(issues > 0 ? " · " : "")
                         + Text(issues > 0 ? "\(issues.formatted()) need attention" : "").foregroundColor(Theme.miss))
                    } else {
                        Text("Analysing \(ActFmt.plural(pending, "file")) · \(pct)% · \(enriched.formatted()) of \(total.formatted()) done"
                             + (issues > 0 ? " · \(issues.formatted()) need attention" : ""))
                    }
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .padding(.top, 3)
                .fixedSize(horizontal: false, vertical: true)
                TaskBar(fraction: settled ? 1 : Double(pct) / 100, live: !settled, done: settled)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TaskCard(border: settled ? Theme.line : Theme.grab.opacity(0.3)))
    }
}

private struct RssSyncCard: View {
    let task: SystemTask
    let latestRun: CommandRun?

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            TaskIconTile(color: task.running ? Theme.grab : Theme.edition, spinning: task.running) {
                Image(systemName: taskIcon(.rss))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("RSS Sync").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                Group {
                    if task.running {
                        HStack(spacing: 5) {
                            ActPulseDot(color: Theme.grab, size: 7, spread: 6)
                            Text("checking indexer feeds…")
                        }
                    } else if let latestRun {
                        Text(TasksLogic.factualLine(latestRun))
                    } else {
                        Text(task.lastResult.map { "Last: \($0)" } ?? "Idle")
                    }
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .padding(.top, 3)
                if !task.running {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let last = latestRun.map { " · last \(ActFmt.relative($0.endedAt ?? $0.startedAt, now: context.date))" } ?? ""
                        Text("next sync \(ActFmt.countdown(task.nextRun, now: context.date))\(last)")
                            .font(.system(size: 11.5).monospacedDigit())
                            .foregroundStyle(Theme.dim)
                            .padding(.top, 2)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(TaskCard())
    }
}

private struct ScheduledCard: View {
    let tasks: [SystemTask]

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            TaskIconTile(color: Theme.unaired) { Image(systemName: taskIcon(.refresh)) }
            VStack(alignment: .leading, spacing: 0) {
                Text("Scheduled").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(tasks.map { "\(ActFmt.taskLabel($0.name)) \($0.running ? "running" : ActFmt.countdown($0.nextRun, now: context.date))" }
                        .joined(separator: " · "))
                        .font(.system(size: 12.5).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                        .padding(.top, 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(TaskCard())
    }
}

// MARK: - Running rows

private struct RunningRow: View {
    let run: CommandRun
    let queued: Bool
    let playful: Bool
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let pct = TasksLogic.progressPct(run)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 13) {
                TaskIconTile(color: Theme.grab, spinning: !queued && !reduce) { TaskSpinnerGlyph() }
                VStack(alignment: .leading, spacing: 0) {
                    TaskNameLine(run: run)
                    TaskFactLine(run: run)
                    TaskBar(fraction: queued ? 0 : (pct ?? 1), live: !queued && pct == nil)
                }
            }
            HStack {
                Spacer(minLength: 0)
                Text(ActFmt.relative(run.startedAt))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(TaskCard(border: Theme.grab.opacity(0.3)))
    }
}

/// The live backlog-search card (`SearchRunCard`) with real progress and Stop.
private struct SearchRunCard: View {
    let run: CommandRun
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var open = false
    @State private var stopping = false

    var body: some View {
        if let search = run.search {
            content(search)
        }
    }

    private func content(_ search: SearchProgress) -> some View {
        let stuck = search.stuck
        let tone = stuck ? Theme.miss : Theme.grab
        let pct = TasksLogic.searchPct(search)
        let isStopping = stopping || search.stopped
        return HStack(alignment: .top, spacing: 12) {
            TaskIconTile(color: tone, spinning: !reduce && !stuck, size: 30, radius: 9, glyph: 15) { TaskSpinnerGlyph() }
            VStack(alignment: .leading, spacing: 0) {
                ActFlow(spacing: 9, lineSpacing: 4) {
                    Text(run.name).font(.system(size: 14.5, weight: .heavy)).foregroundStyle(Theme.txt)
                    Text(stuck ? "⏸ STALLED?" : "● RUNNING")
                        .font(.system(size: 9.5, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(tone)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(tone.opacity(0.16), in: Capsule())
                        .overlay(Capsule().strokeBorder(tone.opacity(0.36)))
                    Text("started \(ActFmt.relative(run.startedAt))")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
                Text(TasksLogic.scopeLine(search))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
                    .padding(.top, 3)
                ActFlow(spacing: 14, lineSpacing: 4) {
                    count("✓", search.grabbed, "grabbed", Theme.done)
                    count("—", search.noRelease, "no release", Theme.mut)
                    count("●", TasksLogic.searchingCount(search), "searching", Theme.grab)
                    count("○", search.queued, "queued", Theme.dim)
                }
                .padding(.top, 10)
                HStack(spacing: 12) {
                    ActProgressBar(fraction: Double(pct) / 100, height: 7,
                                   fill: stuck ? AnyShapeStyle(LinearGradient(colors: [Theme.miss, Theme.danger.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                                               : AnyShapeStyle(LinearGradient(colors: [Theme.edition.opacity(0.9), Theme.grab], startPoint: .leading, endPoint: .trailing)),
                                   shimmer: !stuck)
                    Text("\(search.processed) / \(search.total) · \(pct)%")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.txt)
                        .contentTransition(.numericText(value: Double(search.processed)))
                        .frame(minWidth: 96, alignment: .trailing)
                }
                .padding(.top, 10)
                if stuck {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 13, weight: .semibold))
                        Text("No target has advanced for \(TasksLogic.duration(search.stalledSeconds)) — indexers may be slow or the run is stuck\(search.current.map { " on “\($0)”" } ?? "").")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.miss)
                    .padding(.top, 9)
                } else {
                    HStack(spacing: 9) {
                        Text("Now").fontWeight(.bold).foregroundStyle(Theme.grab)
                        Text(search.current ?? "—").fontWeight(.semibold).foregroundStyle(Theme.txt).lineLimit(1)
                        Spacer(minLength: 0)
                        if let last = search.lastProgressAt {
                            Text("last result \(ActFmt.relative(last))").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                        }
                    }
                    .font(.system(size: 12.5))
                    .padding(.top, 9)
                }
                HStack(spacing: 12) {
                    if search.total > 0 {
                        Button {
                            if reduce { open.toggle() } else { withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.28)) { open.toggle() } }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).rotationEffect(.degrees(open ? 90 : 0))
                                Text(open ? "Hide targets" : "Show all \(search.total) targets")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                    Button {
                        stop()
                    } label: {
                        Text(isStopping ? "Stopping…" : "■ Stop")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.danger.opacity(0.42)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isStopping)
                    .opacity(isStopping ? 0.65 : 1)
                }
                .padding(.top, 12)
                if open {
                    scope(search)
                        .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .actWash(tone, radius: 11, base: Theme.card, border: tone.opacity(stuck ? 0.34 : 0.24))
    }

    private func count(_ glyph: String, _ value: Int, _ label: String, _ color: Color) -> some View {
        (Text("\(glyph) ") + Text("\(value)").font(.system(size: 12, weight: .heavy, design: .monospaced)) + Text(" \(label)"))
            .font(.system(size: 12))
            .foregroundStyle(color)
    }

    private func scope(_ search: SearchProgress) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                ForEach(TasksLogic.groupTargets(search.targets)) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(group.group).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.txt)
                            if group.tier != nil {
                                let uhd = TasksLogic.isUhd(group.tier)
                                let color = uhd ? QualityTier.uhd.color : QualityTier.hd.color
                                Text(uhd ? "UHD·4K" : "HD·1080p")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(color)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(color.opacity(0.4)))
                            }
                        }
                        ActFlow(spacing: 7, lineSpacing: 7) {
                            ForEach(Array(group.targets.enumerated()), id: \.offset) { _, target in
                                targetPill(target)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 280)
        .padding(.top, 12)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .padding(.top, 13)
    }

    private func targetPill(_ target: SearchScopeTarget) -> some View {
        let (color, dot, glyph): (Color, Color, String) = {
            switch target.state {
            case "grabbed": return (Theme.done, Theme.done, " ✓")
            case "searching": return (Theme.grab, Theme.grab, " ●")
            case "no_release": return (Theme.dim, Theme.dim, " —")
            default: return (Theme.mut, Theme.dim.opacity(0.6), "")
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(target.label + glyph)
        }
        .font(.system(size: 11.5, design: .monospaced))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Theme.panel2, in: Capsule())
        .overlay(Capsule().strokeBorder(target.state == "grabbed" || target.state == "searching" ? color.opacity(0.36) : Theme.line))
    }

    private func stop() {
        stopping = true
        Task {
            do {
                try await model.client?.cancelRun(id: run.id)
                onChanged()
            } catch {
                stopping = false
                toaster.error(error)
            }
        }
    }
}

// MARK: - Recent

private struct RecentGroupView: View {
    let group: TasksLogic.RunGroup
    let tasks: [SystemTask]
    @State private var expanded = false
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RecentRow(run: group.latest, tasks: tasks)
            if !group.older.isEmpty {
                Button {
                    if reduce { expanded.toggle() } else { withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() } }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                        Text(TasksLogic.earlierLabel(group))
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                    .padding(.leading, 16)
                    .padding(.trailing, 14)
                    .padding(.vertical, 8)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(expanded ? .isSelected : [])
                if expanded {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(group.older) { run in RecentRow(run: run, tasks: tasks) }
                    }
                    .padding(.leading, 16)
                    .transition(reduce ? .identity : .opacity.combined(with: .offset(y: -4)))
                }
            }
        }
    }
}

private struct RecentRow: View {
    let run: CommandRun
    let tasks: [SystemTask]
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var open = false

    var body: some View {
        let expandable = run.releases > 0 || run.evaluated > 0 || run.skippedInFlight == true
        let stuck = TasksLogic.isStuckNoGrab(run)
        let kind = TasksLogic.iconKind(run)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    toggle()
                } label: {
                    HStack(alignment: .center, spacing: 13) {
                        TaskIconTile(color: stuck ? Theme.miss : taskIconColor(kind)) { Image(systemName: taskIcon(kind)) }
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card).padding(-4))
                        VStack(alignment: .leading, spacing: 0) {
                            TaskNameLine(run: run)
                            TaskFactLine(run: run)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!expandable)
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Text(ActFmt.relative(run.endedAt ?? run.startedAt))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                    if expandable {
                        Button(action: toggle) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.dim)
                                .rotationEffect(.degrees(open ? 90 : 0))
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(open ? "Hide decision trail" : "Show decision trail")
                    }
                    actions
                }
                .frame(minHeight: 30)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            if expandable && open {
                RunTrail(runId: run.id)
                    .transition(reduce ? .identity : .opacity)
            }
        }
        .modifier(TaskCard(border: stuck ? Theme.miss.opacity(0.35) : Theme.line))
    }

    private func toggle() {
        if reduce { open.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } }
    }

    /// `RunActions`: Open (item runs), Search again, Run {Task} again.
    @ViewBuilder
    private var actions: some View {
        let sched = TasksLogic.schedulerTask(for: run, in: tasks)
        let title = run.targetTitle ?? run.name
        if run.itemId != nil || sched != nil {
            HStack(spacing: 0) {
                if let itemId = run.itemId {
                    ActIconButton(systemImage: "arrow.up.right.square", label: "Open \(title) in library", tint: Theme.mut) { model.open(itemId) }
                }
                ActMoreMenu {
                    if let itemId = run.itemId {
                        Button("Search again", systemImage: "magnifyingglass") {
                            Task { await ActActions.search(model.client, toaster, itemId: itemId, message: "Searching again for \(title)") }
                        }
                    }
                    if let sched {
                        let label = ActFmt.taskLabel(sched.name)
                        Button("Run \(label) again", systemImage: "arrow.clockwise") {
                            Task {
                                do {
                                    try await model.client?.runTask(name: sched.name)
                                    toaster.show("\(label) started")
                                } catch { toaster.error(error) }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Decision trail

private struct RunTrail: View {
    let runId: Int
    @Environment(AppModel.self) private var model
    @State private var detail: CommandRunDetail?
    @State private var failed = false
    @State private var rawList = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let detail {
                trail(detail.candidates)
            } else if failed {
                note("The decision trail could not be loaded.")
            } else {
                note("Loading the decision trail…")
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .task {
            do { detail = try await model.client?.systemRun(id: runId) } catch { failed = true }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Theme.mut)
    }

    @ViewBuilder
    private func trail(_ candidates: [RunCandidate]) -> some View {
        let grabbed = candidates.filter { $0.action == "GRAB" || $0.action == "UPGRADE" }
        let passed = candidates.filter { $0.action == "REJECT" || $0.action == "SKIP" }
        if grabbed.isEmpty && passed.isEmpty {
            note("No releases were considered on this pass.")
        } else {
            let groups = TasksLogic.groupByReason(passed)
            if rawList {
                trailGroup("Grabbed / Upgraded", grabbed.map { TasksLogic.DedupRow(rep: $0, count: 1, indexers: 1) })
                trailGroup("Passed / Skipped", passed.map { TasksLogic.DedupRow(rep: $0, count: 1, indexers: 1) })
            } else {
                if !groups.isEmpty { VerdictStrip(groups: groups, grabbedCount: grabbed.count, evaluated: passed.count) }
                VStack(alignment: .leading, spacing: 6) {
                    trailLabel("Grabbed / Upgraded")
                    let rows = TasksLogic.dedupe(grabbed)
                    if rows.isEmpty {
                        Text("Nothing grabbed this pass — nothing found beat what you already have.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    } else {
                        ForEach(rows) { row in CandidateLine(row: row) }
                    }
                }
                if !groups.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        trailLabel("Passed / Skipped · grouped by reason")
                        VStack(spacing: 8) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                ReasonGroupView(group: group, defaultOpen: index == 0)
                            }
                        }
                    }
                }
            }
            if !passed.isEmpty {
                (Text("\(ActFmt.plural(passed.count, "release")) → \(ActFmt.plural(groups.count, "reason")). Reposts across indexers are folded (the ×N badge). "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
                Button(rawList ? "Show the grouped view" : "Show the raw list") { rawList.toggle() }
                    .font(.system(size: 12))
                    .foregroundStyle(ActColor.segText)
                    .buttonStyle(.plain)
            }
        }
    }

    private func trailLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(0.5).foregroundStyle(Theme.dim)
    }

    @ViewBuilder
    private func trailGroup(_ label: String, _ rows: [TasksLogic.DedupRow]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                trailLabel(label)
                ForEach(rows) { row in CandidateLine(row: row) }
            }
        }
    }
}

private struct VerdictStrip: View {
    let groups: [TasksLogic.ReasonGroup]
    let grabbedCount: Int
    let evaluated: Int
    @Environment(\.actReduceMotion) private var reduce
    @State private var grown = false

    var body: some View {
        let total = max(groups.reduce(0) { $0 + $1.total }, 1)
        VStack(alignment: .leading, spacing: 11) {
            ActFlow(spacing: 10, lineSpacing: 2) {
                Text(grabbedCount > 0 ? "Why the rest were passed over" : "Why nothing was grabbed")
                    .font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                Text("\(ActFmt.plural(evaluated, "release")), grouped by reason").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(groups) { group in
                        Rectangle().fill(group.bucket.tone.color)
                            .frame(width: max(0, (geo.size.width - CGFloat(groups.count - 1)) * CGFloat(group.total) / CGFloat(total) * (reduce || grown ? 1 : 0)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 10)
            .background(Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.line))
            ActFlow(spacing: 16, lineSpacing: 8) {
                ForEach(groups) { group in
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 3).fill(group.bucket.tone.color).frame(width: 9, height: 9)
                        (Text(group.bucket.label + " ") + Text("\(group.total)").bold().foregroundColor(Theme.txt))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.mut)
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
        .onAppear {
            guard !reduce else { return }
            withAnimation(ActMotion.reveal(0.6)) { grown = true }
        }
    }
}

private struct ReasonGroupView: View {
    let group: TasksLogic.ReasonGroup
    @State private var open: Bool
    @Environment(\.actReduceMotion) private var reduce

    init(group: TasksLogic.ReasonGroup, defaultOpen: Bool) {
        self.group = group
        _open = State(initialValue: defaultOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if reduce { open.toggle() } else { withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3)) { open.toggle() } }
            } label: {
                HStack(spacing: 12) {
                    Circle().fill(group.bucket.tone.color).frame(width: 10, height: 10)
                    (Text(group.bucket.label).font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.txt)
                     + Text(group.qualifier.map { " · \($0)" } ?? "").font(.system(size: 12)).foregroundColor(Theme.mut))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    (Text("\(group.total)").fontWeight(.bold).foregroundColor(Theme.txt) + Text(group.total == 1 ? " release" : " releases"))
                        .font(.system(size: 11.5).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .background(Theme.panel2, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(group.rows) { row in CandidateLine(row: row) }
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 6)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
    }
}

/// One candidate line (`.tline`): dot, release, group, size, ×N, why.
private struct CandidateLine: View {
    let row: TasksLogic.DedupRow

    var body: some View {
        let c = row.rep
        let dot: Color = c.action == "GRAB" ? Theme.done : (c.action == "UPGRADE" ? Theme.grab : (c.action == "REJECT" ? Theme.miss : Theme.dim))
        let whyColor: Color = (c.action == "GRAB" || c.action == "UPGRADE") ? Theme.done : (c.action == "REJECT" ? Theme.miss : Theme.mut)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 9) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(c.releaseTitle).foregroundStyle(Theme.txt).lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let group = c.releaseGroup { Text(group).foregroundStyle(Theme.edition).lineLimit(1).fixedSize() }
                if let size = c.size { Text(ActFmt.bytes(size)).foregroundStyle(Theme.dim).fixedSize() }
                if row.count > 1 || row.indexers > 1 {
                    Text("×\(row.count)\(row.indexers > 1 ? " · \(row.indexers) indexers" : "")")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
                        .fixedSize()
                }
            }
            Text(why(c))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(whyColor)
                .lineLimit(2)
                .padding(.leading, 17)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1).mask(
                HStack(spacing: 3) { ForEach(0..<80, id: \.self) { _ in Rectangle().frame(width: 4) } })
        }
    }

    private func why(_ c: RunCandidate) -> String {
        if let score = c.cfScore, score != 0 {
            let signed = score > 0 ? "+\(score)" : "\(score)"
            return c.reason.isEmpty ? signed : "\(c.reason) · \(signed)"
        }
        return c.reason.isEmpty ? "—" : c.reason
    }
}
