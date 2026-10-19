import Foundation

/// The "nothing grabbed" toast's pause note (search-pauses.ts `pauseToastNote`):
/// when the scope was auto-paused, say why, so an empty manual search reads as
/// "auto wasn't trying; your manual run went anyway".
public enum SearchPauseNote {
    /// The soonest-resuming active cooldown for the episode in the scoped versions.
    public static func cooldown(_ pauses: SearchPauses?, episodeId: Int, versionIds: Set<Int>) -> EpisodePause? {
        (pauses?.episodes ?? [])
            .filter { $0.episodeId == episodeId && versionIds.contains($0.editionId ?? -1) && $0.cooldownUntil != nil }
            .min { ($0.cooldownUntil ?? "") < ($1.cooldownUntil ?? "") }
    }

    /// The soonest-resuming empty-search backoff for the season (item-wide rows count too).
    public static func backoff(_ pauses: SearchPauses?, season: Int, versionIds: Set<Int>) -> SeasonPause? {
        (pauses?.seasons ?? [])
            .filter { ($0.seasonNumber == season || $0.seasonNumber == nil) && versionIds.contains($0.editionId ?? -1)
                && $0.backoffUntil != nil }
            .min { ($0.backoffUntil ?? "") < ($1.backoffUntil ?? "") }
    }

    public static func note(cooldown: EpisodePause?, backoff: SeasonPause?, clock: (Date) -> String) -> String? {
        if let cooldown {
            let n = cooldown.failedDownloadCount ?? 0
            let at = DetailText.instant(cooldown.cooldownUntil).map(clock) ?? "soon"
            return "auto-search was cooling down after \(n) failed \(n == 1 ? "download" : "downloads") (resumes \(at)) — your manual search ran anyway"
        }
        if let backoff {
            let n = backoff.consecutiveEmpty ?? 0
            let at = DetailText.instant(backoff.backoffUntil).map(clock) ?? "soon"
            return "auto-search was paused after \(n) empty \(n == 1 ? "search" : "searches") (resumes \(at)) — your manual search ran anyway"
        }
        return nil
    }

    /// "Searched S1E2 — nothing grabbed", plus the note when there is one.
    public static func nothingGrabbed(_ label: String, note: String?) -> String {
        let base = "Searched \(label) — nothing grabbed"
        return note.map { "\(base) · \($0)" } ?? base
    }
}
