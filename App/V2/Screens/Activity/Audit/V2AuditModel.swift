import SwiftUI
import FusionhaKit

/// The Audit scope's data and calls (v1 `ActivityAuditTab`'s, kept as they
/// are): the server's category counts, the Who list, the filters and the
/// pages of 100 with Load older.
@MainActor
@Observable
final class V2AuditModel {
    private(set) var items: [AuditEntry] = []
    private(set) var counts: AuditCounts?
    private(set) var actors: [AuditActor] = []
    private(set) var loaded = false
    private(set) var failed = false
    private(set) var hasMore = false
    private(set) var loadingMore = false
    var filter = AuditFilter()

    static let pageSize = 100

    static let windows: [(key: String, label: String)] = [
        ("24h", "Last 24 h"), ("7d", "Last 7 days"), ("30d", "Last 30 days"), ("all", "All time"),
    ]

    /// Reloads whenever one of these changes.
    func reloadKey(search: String) -> String {
        "\(filter.category ?? "")|\(filter.who ?? "")|\(filter.since)|\(filter.sensitive)|\(search)"
    }

    var unfiltered: Bool { filter == AuditFilter() }

    var whoLabel: String? {
        filter.who.flatMap { key in actors.first { $0.key == key }?.label }
    }

    var windowLabel: String? {
        filter.since == "all" ? nil : Self.windows.first { $0.key == filter.since }?.label
    }

    func loadActors(_ client: APIClient?) async {
        actors = (try? await client?.auditActors()) ?? actors
    }

    func reload(_ client: APIClient?, search: String) async {
        guard let client else { return }
        let effective = effective(search)
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

    func loadOlder(_ client: APIClient?, search: String) async {
        guard !loadingMore, let last = items.last, let client else { return }
        loadingMore = true
        defer { loadingMore = false }
        guard let page = try? await client.audit(effective(search), limit: Self.pageSize, beforeId: last.id) else { return }
        let seen = Set(items.map(\.id))
        items += page.filter { !seen.contains($0.id) }
        hasMore = page.count == Self.pageSize
    }

    private func effective(_ search: String) -> AuditFilter {
        var f = filter
        f.query = search
        return f
    }
}

/// How an audit row reads (v1 `AuditRow`'s rules without the hues).
enum V2AuditCopy {
    static func readable(_ entry: AuditEntry) -> Bool { !(entry.verb ?? "").isEmpty }

    static func who(_ entry: AuditEntry) -> String {
        entry.actorLabel.flatMap { $0.isEmpty ? nil : $0 } ?? AuditLogic.actorName(entry.actor)
    }

    static func kind(_ entry: AuditEntry) -> String? {
        AuditFilter.categories.first { $0.key == entry.category }?.label
    }

    /// The line under the title: the verb, or the whole sentence when the
    /// row names no title (legacy rows: the route's label).
    static func headline(_ entry: AuditEntry) -> String {
        if entry.titleTarget != nil { return entry.verb ?? "" }
        return readable(entry) ? (entry.verbFull ?? entry.verb ?? "") : AuditLogic.resolve(entry.action).label
    }

    /// A deletion or a revoke reads in the danger ink (legacy rows only
    /// carry it; readable rows are one ink).
    static func destructive(_ entry: AuditEntry) -> Bool {
        !readable(entry) && AuditLogic.resolve(entry.action).tone == .danger
    }

    static func icon(_ entry: AuditEntry) -> String {
        guard readable(entry) else { return AuditLogic.resolve(entry.action).tone.icon }
        switch entry.category {
        case "AUTO_FIX": return "wrench.and.screwdriver"
        case "SELF_SERVICE": return "hand.tap"
        case "REQUEST": return "tray.and.arrow.down"
        default: return entry.actorType == "token" || entry.actorType == "key" ? "key" : "person"
        }
    }

    /// "Legacy route" target, shown when a legacy row names one.
    static func target(_ entry: AuditEntry) -> String? {
        guard !readable(entry), let t = entry.target?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return "on \(t)"
    }
}
