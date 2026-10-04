import SwiftUI
import Charts
import FusionhaKit

// Activity · Audit (`routes/activity/AuditTab.tsx`, `lib/audit-format.ts`) and
// Activity · Indexers (`routes/activity/IndexersTab.tsx` → FleetOverview).

// MARK: - Audit logic (lib/audit-format.ts)

fileprivate enum AuditTone {
    case ok, warn, danger, neutral

    var color: Color {
        switch self {
        case .ok: return Theme.done
        case .warn: return Theme.stuck
        case .danger: return Theme.danger
        case .neutral: return Theme.dim
        }
    }

    var icon: String {
        switch self {
        case .ok: return "plus"
        case .warn: return "pencil"
        case .danger: return "trash"
        case .neutral: return "clock.arrow.circlepath"
        }
    }
}

fileprivate enum AuditCategory: String, CaseIterable, Hashable {
    case added, changed, deleted

    var label: String {
        switch self {
        case .added: return "Added"
        case .changed: return "Changed"
        case .deleted: return "Deleted"
        }
    }

    var tone: AuditTone {
        switch self {
        case .added: return .ok
        case .changed: return .warn
        case .deleted: return .danger
        }
    }
}

fileprivate enum AuditLogic {
    static func parse(_ action: String) -> (method: String, route: String) {
        guard let space = action.firstIndex(of: " ") else { return (action, "") }
        return (String(action[..<space]), String(action[action.index(after: space)...]))
    }

    static func actorName(_ actor: String) -> String {
        if actor == "trusted-key" { return "Trusted key" }
        if actor == "anonymous" { return "Anonymous" }
        if actor.hasPrefix("instance:") { return "Connected instance" }
        if actor.hasPrefix("user:") {
            let parts = actor.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            if parts.count >= 3, !parts[2].isEmpty {
                return parts.count > 3 && parts[3] == "pat" ? "\(parts[2]) · API token" : parts[2]
            }
            if parts.count > 1, !parts[1].isEmpty { return "Deleted user #\(parts[1])" }
            return "Deleted user"
        }
        return actor
    }

    private static let rules: [(method: String, pattern: String, label: String, tone: AuditTone)] = [
        ("POST", "/requests/[^/]+/approve$", "Approved a request", .ok),
        ("POST", "/requests/[^/]+/reject$", "Rejected a request", .warn),
        ("POST", "/requests$", "Submitted a request", .neutral),
        ("DELETE", "/requests/[^/]+$", "Withdrew a request", .neutral),
        ("DELETE", "/library/[^/]+$", "Deleted a title", .danger),
        ("POST", "/library$", "Added a title", .ok),
        ("POST", "/library/[^/]+/editions$", "Added an edition", .ok),
        ("DELETE", "/editions/[^/]+$", "Removed an edition", .danger),
        ("DELETE", "/blocklist/all$", "Cleared the entire blocklist", .danger),
        ("DELETE", "/blocklist/[^/]+$", "Cleared a blocklist entry", .warn),
        ("POST", "/blocklist", "Blocklisted a release", .danger),
        ("POST", "/grab$", "Grabbed a release", .ok),
        ("POST", "/search$", "Ran a search", .neutral),
        ("POST", "/users$", "Created a user", .ok),
        ("DELETE", "/users/[^/]+$", "Deleted a user", .danger),
        ("POST", "/grants$", "Granted access", .ok),
        ("DELETE", "/grants/[^/]+$", "Revoked access", .danger),
    ]

    private static func matches(_ route: String, _ pattern: String) -> Bool {
        route.range(of: pattern, options: .regularExpression) != nil
    }

    static func resolve(_ action: String) -> (label: String, tone: AuditTone) {
        let (method, route) = parse(action)
        if let rule = rules.first(where: { $0.method == method && matches(route, $0.pattern) }) {
            return (rule.label, rule.tone)
        }
        if (method == "PUT" || method == "PATCH") && matches(route, "/(settings|config)\\b") {
            return ("Changed a setting", .warn)
        }
        if ["POST", "PUT", "PATCH"].contains(method) && matches(route, "/roles\\b") {
            return ("Changed a role", .warn)
        }
        let m = method.uppercased()
        let tone: AuditTone = m == "DELETE" ? .danger : (m == "PUT" || m == "PATCH" ? .warn : (m == "POST" ? .ok : .neutral))
        let segments = route.split(separator: "/").map(String.init)
        let segment = segments.reversed().first { !$0.hasPrefix("{") } ?? segments.last ?? ""
        let words = segment.replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let titled = method.isEmpty ? method : method.prefix(1).uppercased() + method.dropFirst().lowercased()
        return (words.isEmpty ? titled : "\(titled) \(words)", tone)
    }

    static func category(_ tone: AuditTone) -> AuditCategory? {
        switch tone {
        case .ok: return .added
        case .warn: return .changed
        case .danger: return .deleted
        case .neutral: return nil
        }
    }

    static func initials(_ name: String) -> String {
        let parts = name.split(whereSeparator: \.isWhitespace)
        guard let first = parts.first else { return "?" }
        if parts.count == 1 { return String(first.prefix(2)).uppercased() }
        return (String(first.prefix(1)) + String(parts[parts.count - 1].prefix(1))).uppercased()
    }
}

// MARK: - Audit tab

struct ActivityAuditTab: View {
    @Environment(AppModel.self) private var model
    @Environment(\.actReduceMotion) private var reduce
    @State private var items: [AuditEntry] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var hasMore = false
    @State private var loadingMore = false
    @State private var filter: AuditCategory?

    private static let pageSize = 100

    private struct RowsKey: Equatable {
        let count: Int
        let filter: AuditCategory?
    }

    var body: some View {
        ActivityPage {
            if !loaded {
                ActEmpty(message: "Loading audit log…")
            } else if failed && items.isEmpty {
                ActEmpty(message: "The audit log could not be loaded. Check the backend and try again.")
            } else if items.isEmpty {
                ActEmpty(message: "No audited requests yet. Every write the API makes shows up here.")
            } else {
                loadedView
            }
        }
        .animation(reduce ? nil : ActMotion.rows, value: RowsKey(count: items.count, filter: filter))
        .task {
            do {
                let page = try await model.client?.audit(limit: Self.pageSize) ?? []
                items = page
                hasMore = page.count == Self.pageSize
                failed = false
            } catch {
                failed = true
            }
            loaded = true
        }
    }

    /// Flat children of the page's lazy stack (one per row).
    @ViewBuilder
    private var loadedView: some View {
        let shown = filter.map { f in items.filter { AuditLogic.category(AuditLogic.resolve($0.action).tone) == f } } ?? items
        chips.padding(.bottom, 12)
        if shown.isEmpty {
            ActEmpty(message: "No \(filter.map { "\($0.label) " } ?? "")events in the loaded rows\(hasMore ? " yet — load more below." : ".")")
        } else {
            let last = shown.count - 1
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, entry in
                AuditRow(entry: entry)
                    .actReveal(index, stagger: 0.02)
                    .padding(.leading, 26)
                    .padding(.bottom, index == last ? 0 : 10)
                    .background(alignment: .leading) { ActTimelineSegment(first: index == 0, last: index == last) }
                    .actRowTransition(reduce)
            }
        }
        footer
    }

    private var chips: some View {
        var counts: [AuditCategory: Int] = [:]
        for entry in items {
            if let c = AuditLogic.category(AuditLogic.resolve(entry.action).tone) { counts[c, default: 0] += 1 }
        }
        return ActFlow(spacing: 8, lineSpacing: 8) {
            ActChip(label: "All", count: items.count, accent: Theme.grab, selected: filter == nil) { filter = nil }
            ForEach(AuditCategory.allCases, id: \.self) { c in
                if (counts[c] ?? 0) > 0 {
                    ActChip(label: c.label, count: counts[c], accent: c.tone.color, selected: filter == c) { filter = c }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        Group {
            if loadingMore {
                Text("Loading more…")
            } else if hasMore {
                Button("Load older") { Task { await loadOlder() } }
                    .buttonStyle(ActButtonStyle(kind: .ghost))
            } else {
                Text("You’ve reached the end · \(items.count.formatted()) loaded")
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.dim)
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private func loadOlder() async {
        guard !loadingMore, let last = items.last else { return }
        loadingMore = true
        defer { loadingMore = false }
        guard let page = try? await model.client?.audit(limit: Self.pageSize, beforeId: last.id) else { return }
        let seen = Set(items.map(\.id))
        items += page.filter { !seen.contains($0.id) }
        hasMore = page.count == Self.pageSize
    }
}

private struct AuditRow: View {
    let entry: AuditEntry

    var body: some View {
        let resolved = AuditLogic.resolve(entry.action)
        let actor = AuditLogic.actorName(entry.actor)
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 11) {
                    Text(AuditLogic.initials(actor))
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.2)
                        .foregroundStyle(Theme.txt)
                        .frame(width: 30, height: 30)
                        .background(Theme.panel2, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.line))
                        .accessibilityHidden(true)
                    ActFlow(spacing: 8, lineSpacing: 4) {
                        Text(actor).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                        Text(resolved.label).font(.system(size: 13.5)).foregroundStyle(Theme.mut)
                        if let target = entry.target?.trimmingCharacters(in: .whitespaces), !target.isEmpty {
                            ActMonoChip(text: "on \(target)", color: Theme.dim)
                        }
                    }
                    .padding(.top, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    Text(ActFmt.relative(entry.at)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim)
                    Text(ActFmt.dateTime(entry.at)).font(.system(size: 11, design: .monospaced).monospacedDigit()).foregroundStyle(Theme.dim)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .actWash(resolved.tone.color)
            Circle()
                .fill(Theme.bg)
                .overlay(Circle().fill(resolved.tone.color.opacity(0.24)))
                .overlay(Image(systemName: resolved.tone.icon).font(.system(size: 10, weight: .bold)).foregroundStyle(resolved.tone.color))
                .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
                .frame(width: 22, height: 22)
                .offset(x: -26, y: 14)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Indexers tab (FleetOverview)

struct ActivityIndexersTab: View {
    @Environment(AppModel.self) private var model
    @Environment(\.actReduceMotion) private var reduce
    @State private var range = "7d"
    @State private var stats: ActivityIndexerStats?
    @State private var failed = false
    @State private var othersOpen = false
    @State private var grown = false

    private static let ranges: [(String, String)] = [("24h", "24h"), ("7d", "7d"), ("30d", "30d"), ("all", "All-time")]
    private static let palette: [Color] = [Theme.indigo, Theme.cyan, Theme.done, Theme.edition, Theme.miss]

    private var phrase: String {
        switch range {
        case "24h": return "last 24h"
        case "30d": return "last 30 days"
        case "all": return "all-time"
        default: return "last 7 days"
        }
    }

    var body: some View {
        ActivityPage {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let stats {
                    kpis(stats)
                    shareCard(stats)
                    activityCard(stats.summary)
                } else if failed {
                    ActEmpty(message: "Indexer stats could not be loaded. Check the backend and try again.")
                } else {
                    ActEmpty(message: "Loading indexer stats…")
                }
            }
        }
        .task(id: range) {
            do {
                let result = try await model.client?.activityIndexerStats(range: range)
                if reduce { stats = result } else { withAnimation(ActMotion.reveal()) { stats = result } }
                failed = false
                grown = false
                if reduce { grown = true } else { withAnimation(ActMotion.reveal(0.7).delay(0.05)) { grown = true } }
            } catch {
                failed = stats == nil
            }
        }
    }

    private var header: some View {
        ActFlow(spacing: 10, lineSpacing: 8) {
            Text("Fleet overview").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
            let total = stats?.summary.indexers ?? 0
            Text("\(ActFmt.plural(total, "indexer")) · \(phrase)").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
            ActSegment(options: Self.ranges, selection: $range)
        }
    }

    private func kpis(_ s: ActivityIndexerStats) -> some View {
        let summary = s.summary
        let total = summary.indexers
        let off = summary.off
        let avg = summary.avgSuccessRange.map { Int(($0 * 100).rounded()) }
        return Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
            kpiTile {
                kpiNumber("\(total)")
                (Text("\(summary.healthy) healthy").bold().foregroundColor(Theme.done) + Text(" · ")
                 + Text("\(summary.backoff) backoff").bold().foregroundColor(Theme.miss) + Text(" · \(off) off"))
                    .font(.system(size: 11.5)).foregroundStyle(Theme.mut).padding(.top, 7)
                healthMix([(summary.healthy, Theme.done), (summary.backoff, Theme.miss), (off, Theme.dim)])
                    .padding(.top, 10)
            }
            kpiTile {
                kpiNumber((summary.grabsRange ?? 0).formatted())
                Text("grabs · \(phrase)").font(.system(size: 11.5)).foregroundStyle(Theme.mut).padding(.top, 7)
            }
            }
            GridRow {
            kpiTile {
                kpiNumber((summary.queriesRange ?? 0).formatted())
                Text("API queries · \(phrase)").font(.system(size: 11.5)).foregroundStyle(Theme.mut).padding(.top, 7)
                if let series = summary.activitySeries, !series.isEmpty {
                    sparkline(series, color: Theme.grab).frame(width: 90, height: 34).padding(.top, 6)
                }
            }
            kpiTile {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle().stroke(Theme.txt.opacity(0.08), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: CGFloat(avg ?? 0) / 100 * (grown ? 1 : 0))
                            .stroke((avg ?? 0) < 90 ? Theme.miss : Theme.done, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 34, height: 34)
                    (Text(avg.map { "\($0)" } ?? "—") + Text(avg == nil ? "" : "%").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.dim))
                        .font(.system(size: 30, weight: .heavy).monospacedDigit())
                        .tracking(-0.9)
                        .foregroundStyle(Theme.done)
                }
                Text("avg success · \(phrase)").font(.system(size: 11.5)).foregroundStyle(Theme.mut).padding(.top, 7)
            }
            }
        }
    }

    private func kpiTile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, minHeight: 84, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func kpiNumber(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy).monospacedDigit())
            .tracking(-0.9)
            .foregroundStyle(Theme.txt)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
    }

    /// The healthy / backoff / off mix bar (`flex: n` segments, scaleX in).
    private func healthMix(_ segs: [(Int, Color)]) -> some View {
        let weights = segs.map { max(Double($0.0), 0.001) }
        let sum = weights.reduce(0, +)
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segs.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(segs[i].1)
                        .frame(width: max(0, (geo.size.width - CGFloat(segs.count - 1) * 2) * CGFloat(weights[i] / sum)))
                }
            }
            .scaleEffect(x: grown ? 1 : 0, anchor: .leading)
        }
        .frame(height: 6)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private struct Share: Identifiable {
        let id: String
        let name: String
        let pct: Double
        let grabs: Int
        let color: Color
        let isOthers: Bool
    }

    private func shareCard(_ s: ActivityIndexerStats) -> some View {
        let fleet = s.summary.grabsRange ?? s.indexers.reduce(0) { $0 + ($1.grabsRange ?? 0) }
        let sorted = s.indexers.filter { ($0.grabsRange ?? 0) > 0 }.sorted { ($0.grabsRange ?? 0) > ($1.grabsRange ?? 0) }
        let share: (Int) -> Double = { fleet > 0 ? Double($0) / Double(fleet) * 100 : 0 }
        var entries: [Share] = sorted.prefix(5).enumerated().map { i, ix in
            Share(id: "\(ix.id)", name: ix.name, pct: share(ix.grabsRange ?? 0), grabs: ix.grabsRange ?? 0,
                  color: Self.palette[i % Self.palette.count], isOthers: false)
        }
        let rest = Array(sorted.dropFirst(5))
        if !rest.isEmpty {
            let restGrabs = rest.reduce(0) { $0 + ($1.grabsRange ?? 0) }
            entries.append(Share(id: "others", name: "\(rest.count) other\(rest.count > 1 ? "s" : "")", pct: share(restGrabs),
                                 grabs: restGrabs, color: Theme.dim, isOthers: true))
        }
        let others = rest.map { Share(id: "\($0.id)", name: $0.name, pct: share($0.grabsRange ?? 0), grabs: $0.grabsRange ?? 0, color: Theme.dim, isOthers: false) }
        return VStack(alignment: .leading, spacing: 12) {
            cardHeading("Grab share — who's pulling weight")
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(entries) { e in
                        Rectangle().fill(e.color)
                            .frame(width: max(0, (geo.size.width - CGFloat(max(entries.count - 1, 0)) * 2) * CGFloat(e.pct / 100)))
                    }
                    Spacer(minLength: 0)
                }
                .scaleEffect(x: grown ? 1 : 0, anchor: .leading)
            }
            .frame(height: 14)
            .background(Theme.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entries) { e in
                    if e.isOthers {
                        Button {
                            if reduce { othersOpen.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { othersOpen.toggle() } }
                        } label: {
                            legendRow(e, caret: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        legendRow(e, caret: false)
                    }
                }
                if othersOpen {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(others) { o in legendRow(o, caret: false) }
                    }
                    .padding(.leading, 18)
                }
                if entries.isEmpty {
                    Text("No grabs in this window yet.").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func legendRow(_ e: Share, caret: Bool) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 3).fill(e.color).frame(width: 9, height: 9)
            HStack(spacing: 4) {
                Text(e.name).foregroundStyle(Theme.txt).lineLimit(1)
                if caret {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(othersOpen ? 90 : 0))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.1f%%", e.pct)).font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.txt)
            Text("\(e.grabs.formatted()) grabs").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
        }
        .font(.system(size: 12.5))
        .contentShape(Rectangle())
    }

    private func activityCard(_ summary: ActivityIndexerSummary) -> some View {
        let series = summary.activitySeries ?? []
        let peak = series.max() ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            cardHeading("Activity · \(phrase) (all indexers)")
            (Text((summary.queriesRange ?? 0).formatted()) + Text(" queries").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.dim))
                .font(.system(size: 24, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.txt)
            Text(peak > 0 ? "peak \(peak.formatted()) / bucket" : "—")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.dim)
                .padding(.top, 2)
            if !series.isEmpty {
                sparkline(series, color: Theme.cyan).frame(height: 72).padding(.top, 10)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func cardHeading(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.95)
            .foregroundStyle(Theme.dim)
            .padding(.bottom, 12)
    }

    private func sparkline(_ values: [Int], color: Color) -> some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                AreaMark(x: .value("Bucket", index), y: .value("Queries", grown ? value : 0))
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Bucket", index), y: .value("Queries", grown ? value : 0))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(values.max() ?? 0, 1))
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }
}
