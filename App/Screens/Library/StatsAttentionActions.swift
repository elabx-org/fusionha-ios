import SwiftUI
import FusionhaKit

/// What a "Needs attention" row does, shared by the Library stats sheet and
/// the shell's status cluster (the web's `AttentionList` in both places).
/// Callers close their sheet or popover first.
extension AppModel {
    /// The row's action pill.
    func statsAct(_ row: StatsAttentionRow) {
        guard let id = row.itemId else { tab = .activity; return }
        switch row.action {
        case .manualImport: tab = .activity
        case .replace(let tier): interactiveSearch(id, tier: tier)
        case .setType: edit(id)
        case .review, .view, .seeWhy: open(id)
        }
    }

    /// Tapping the row itself.
    func statsOpenRow(_ row: StatsAttentionRow) {
        if row.kind == .importHeld { tab = .activity } else if let id = row.itemId { open(id) }
    }

    /// The row's ✕: drop it at once, put it back if the server says no.
    func statsDismiss(_ row: StatsAttentionRow, feed: StatsSheetFeed) {
        guard let client else { return }
        feed.drop(rowId: row.id)
        Task {
            do {
                if let runId = row.runId {
                    try await client.ackRunAttention(runId)
                } else if let itemId = row.dismissItemId {
                    try await client.dismissScopeMismatch(itemId)
                }
            } catch {
                toast(row.runId != nil ? "Couldn't dismiss — the item is back. Try again." : "Couldn't dismiss — try again.",
                      variant: .error)
                await feed.load(client: client, queue: queue)
            }
        }
    }
}
