import SwiftUI
import FusionhaKit

// Activity · Audit (`routes/activity/AuditTab.tsx`, `audit/*`, A9): the
// server-counted category chips, Who, Since and Sensitive only, the shared
// title search, then readable rows (title · year / verb · who · kind / time),
// each opening its detail. Legacy route rows fall back to `AuditLogic`.

struct ActivityAuditTab: View {
    let search: String
    @Environment(AppModel.self) private var model
    @Environment(\.actReduceMotion) private var reduce
    @State private var items: [AuditEntry] = []
    @State private var counts: AuditCounts?
    @State private var actors: [AuditActor] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var hasMore = false
    @State private var loadingMore = false
    @State private var filter = AuditFilter()
    @State private var open: Int?

    private static let pageSize = 100

    var body: some View {
        ActivityPage {
            filters.padding(.bottom, 12)
            if !loaded {
                ActEmpty(message: "Loading audit log…")
            } else if failed && items.isEmpty {
                ActEmpty(message: "The audit log could not be loaded. Check the backend and try again.")
            } else if items.isEmpty {
                ActEmpty(message: filter == AuditFilter() && search.isEmpty
                         ? "No changes recorded yet. Every change made through fusionha shows up here."
                         : "Nothing matches these filters.")
            } else {
                let last = items.count - 1
                ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                    AuditRow(entry: entry, open: open == entry.id) { open = open == entry.id ? nil : entry.id }
                        .actReveal(index, stagger: 0.02)
                        .padding(.bottom, index == last ? 0 : 10)
                        .actRowTransition(reduce)
                }
                footer
            }
        }
        .task(id: "\(filter.category ?? "")|\(filter.who ?? "")|\(filter.since)|\(filter.sensitive)|\(search)") { await reload() }
        .task { actors = (try? await model.client?.auditActors()) ?? [] }
    }

    // MARK: Filters

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            ActFlow(spacing: 8, lineSpacing: 8) {
                ActChip(label: "All", count: counts?.all, accent: Theme.grab, selected: filter.category == nil) { filter.category = nil }
                ForEach(AuditFilter.categories, id: \.key) { c in
                    ActChip(label: c.label, count: counts?.count(c.key), accent: Self.color(c.key),
                            selected: filter.category == c.key) { filter.category = c.key }
                }
            }
            HStack(spacing: 8) {
                Menu {
                    Button("Everyone") { filter.who = nil }
                    ForEach(actors) { a in Button("\(a.label) · \(a.count)") { filter.who = a.key } }
                } label: {
                    GlassMenuLabel(title: filter.who.flatMap { key in actors.first { $0.key == key }?.label } ?? "Who")
                }
                Menu {
                    ForEach([("24h", "Last 24 h"), ("7d", "Last 7 days"), ("30d", "Last 30 days"), ("all", "All time")], id: \.0) { s in
                        Button(s.1) { filter.since = s.0 }
                    }
                } label: {
                    GlassMenuLabel(title: filter.since == "all" ? "Since" : filter.since)
                }
                Toggle(isOn: $filter.sensitive) {
                    Text("Sensitive" + ((counts?.sensitive).map { " \($0)" } ?? "")).font(.system(size: 13, weight: .semibold))
                }
                .toggleStyle(.button)
                .tint(Theme.miss)
            }
            if let omitted = counts?.omittedLookups, omitted > 0 {
                Text("\(omitted.formatted()) lookups in this window are no longer recorded.")
                    .font(.caption).foregroundStyle(Theme.dim)
            }
        }
    }

    static func color(_ category: String?) -> Color {
        switch category {
        case "AUTO_FIX": return Theme.done
        case "SELF_SERVICE": return Theme.grab
        case "ADMIN": return Theme.i1
        case "REQUEST": return Theme.premiere
        default: return Theme.dim
        }
    }

    // MARK: Paging

    @ViewBuilder
    private var footer: some View {
        Group {
            if loadingMore {
                Text("Loading more…")
            } else if hasMore {
                ActAsyncButton(label: "Load older", kind: .ghost) { await loadOlder(); return true }
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

    private var effective: AuditFilter {
        var f = filter
        f.query = search
        return f
    }

    private func reload() async {
        guard let client = model.client else { return }
        do {
            let page = try await client.audit(effective, limit: Self.pageSize)
            items = page
            hasMore = page.count == Self.pageSize
            failed = false
        } catch {
            failed = true
        }
        counts = (try? await client.auditCounts(effective)) ?? counts
        loaded = true
    }

    private func loadOlder() async {
        guard !loadingMore, let last = items.last, let client = model.client else { return }
        loadingMore = true
        defer { loadingMore = false }
        guard let page = try? await client.audit(effective, limit: Self.pageSize, beforeId: last.id) else { return }
        let seen = Set(items.map(\.id))
        items += page.filter { !seen.contains($0.id) }
        hasMore = page.count == Self.pageSize
    }
}

/// One audit row: the poster or group icon, then title · year / verb · who ·
/// kind / where and when; opens to the detail lines and the address.
struct AuditRow: View {
    let entry: AuditEntry
    let open: Bool
    let onTap: () -> Void

    private var readable: Bool { !(entry.verb ?? "").isEmpty }
    private var who: String { entry.actorLabel.flatMap { $0.isEmpty ? nil : $0 } ?? AuditLogic.actorName(entry.actor) }
    private var tone: Color { readable ? ActivityAuditTab.color(entry.category) : AuditLogic.resolve(entry.action).tone.color }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 11) {
                    lead
                    VStack(alignment: .leading, spacing: 3) {
                        if let t = entry.titleTarget {
                            (Text(t.title).fontWeight(.bold) + Text(verbatim: t.year.map { " \($0)" } ?? "").foregroundColor(Theme.mut))
                                .font(.system(size: 14.5)).foregroundStyle(Theme.txt).lineLimit(1)
                            line(entry.verb ?? "")
                        } else {
                            Text(readable ? (entry.verbFull ?? entry.verb ?? "") : AuditLogic.resolve(entry.action).label)
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                                .fixedSize(horizontal: false, vertical: true)
                            if !readable, let target = entry.target?.trimmingCharacters(in: .whitespaces), !target.isEmpty {
                                ActMonoChip(text: "on \(target)", color: Theme.dim)
                            }
                        }
                        HStack(spacing: 6) {
                            Text(who).foregroundStyle(Theme.mut)
                            if let kind = AuditFilter.categories.first(where: { $0.key == entry.category })?.label {
                                Text(kind).font(.system(size: 11, weight: .bold)).foregroundStyle(tone)
                            }
                            if entry.sensitive == true { Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Theme.miss) }
                            Spacer(minLength: 0)
                            Text(ActFmt.relative(entry.at)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim)
                        }
                        .font(.system(size: 12.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if open { details.padding(.leading, 45) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .actWash(tone)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func line(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(Theme.txt).fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var lead: some View {
        if let t = entry.titleTarget, t.posterUrl != nil {
            ActPoster(url: t.posterUrl, title: t.title, size: .sm)
        } else {
            Image(systemName: readable ? icon : AuditLogic.resolve(entry.action).tone.icon)
                .font(.system(size: 13, weight: .bold)).foregroundStyle(tone)
                .frame(width: 34, height: 34)
                .background(tone.opacity(0.16), in: Circle())
        }
    }

    private var icon: String {
        switch entry.category {
        case "AUTO_FIX": return "wrench.and.screwdriver"
        case "SELF_SERVICE": return "hand.tap"
        case "REQUEST": return "tray.and.arrow.down"
        default: return entry.actorType == "token" || entry.actorType == "key" ? "key" : "person"
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array((entry.detail ?? []).enumerated()), id: \.offset) { _, d in
                Text(d).font(.system(size: 12.5)).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
            }
            Text(ActFmt.dateTime(entry.at)).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim)
            if let ip = entry.ip {
                Text([ip, entry.userAgent].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim)
            }
            if !readable { Text(entry.action).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim) }
        }
    }
}
