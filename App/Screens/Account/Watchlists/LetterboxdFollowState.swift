import SwiftUI
import FusionhaKit

/// The followed own watchlist while it is on (web `WatchlistFollowState`,
/// fusionha 0.4.215): the state line and bar, the five counts, the queued /
/// films-read hint, then the not-public / blocked / cut-off notes.
struct LetterboxdFollowState: View {
    let follow: LetterboxdWatchlistFollow

    private var status: String { follow.status ?? "PENDING" }
    private var variant: SyncVariant { SyncProgress.variant(follow.sync) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if status == "PRIVATE" {
                WatchlistAttention(lead: "Your watchlist isn’t public.",
                                   rest: "fusionha can’t read it, so nothing is syncing. fusionha can only follow what’s public on Letterboxd. Set your watchlist to public in your Letterboxd settings to keep it in sync, then press Sync now.",
                                   color: Theme.miss)
            } else {
                SyncStatusView(sync: follow.sync, requested: follow.counts?.requested ?? follow.requestedCount,
                               lastCheckedAt: follow.lastCheckedAt, nextCheckAt: follow.nextCheckAt,
                               lastError: follow.lastError, errorLead: "Couldn’t read the watchlist",
                               barLabel: "Watchlist sync progress")
            }
            SyncCountsView(counts: follow.counts ?? SourceCounts(requested: follow.requestedCount))
            if status != "PRIVATE", let hint {
                Text(hint).font(.footnote).foregroundStyle(Theme.mut)
            }
        }
        .padding(.vertical, 2)
        if status == "BLOCKED" && variant != .error {
            WatchlistAttention(lead: "Letterboxd is blocking fusionha right now.",
                               rest: "It retries on its own. To backfill meanwhile, use the one-time import under Advanced.")
        }
        if status == "DEGRADED", let error = follow.lastError {
            Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.miss)
        }
    }

    /// "1 queued · working through them · 605 films read".
    private var hint: String? {
        let parts = [SyncProgress.queuedHint(follow.counts), follow.itemCount.map { "\($0) films read" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Syncing while it runs, Error when it failed (Blocked keeps its word),
    /// else the source status (web `WatchlistFollow`).
    static func pill(_ follow: LetterboxdWatchlistFollow) -> (text: String, color: Color) {
        let status = follow.status ?? "PENDING"
        let meta = LetterboxdLogic.status(status)
        switch SyncProgress.variant(follow.sync) {
        case .running: return (SyncProgress.syncing, SyncVariant.running.color)
        case .error: return (status == "BLOCKED" ? meta.label : "Error", SyncVariant.error.color)
        default: return (meta.label, meta.tone.color)
        }
    }
}
