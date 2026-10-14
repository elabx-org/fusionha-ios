import SwiftUI
import Charts
import FusionhaKit

// Activity · Audit (`routes/activity/AuditTab.tsx`, `lib/audit-format.ts`) and
// Activity · Indexers (`routes/activity/IndexersTab.tsx` → FleetOverview).

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
        .animation(reduce ? nil : ActMotion.rows, value: RowsKey(filter: filter))
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

struct AuditRow: View {
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
