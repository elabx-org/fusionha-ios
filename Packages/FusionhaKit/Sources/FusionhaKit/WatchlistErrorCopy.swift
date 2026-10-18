import Foundation

/// Error copy for the Plex watchlist and Letterboxd cards (web
/// `plex-watchlist-errors.ts`, `letterboxd-errors.ts`). The server's inner
/// prose is never shown; unknown codes fall back to `ErrorCopy`.
public enum WatchlistErrorCopy {
    public static let fallback = "That didn’t work. Try again in a moment."

    public static let plex: [String: String] = [
        "not_enabled": "An admin hasn’t allowed automatic requests from your Plex watchlist.",
        "ineligible": "Your account can’t use automatic requests right now.",
        "rate_limited": "You can check again in a moment.",
        "policy": "Your account can request HD·1080p only.",
        "list_deleted": "This list no longer exists on Plex.",
        "not_deleted": "Only lists deleted on Plex can be removed.",
        "not_found": "That list wasn’t found. Reopen your account and try again.",
        "secrets_locked": "fusionha can’t save your Plex sign-in right now. Ask an admin.",
        "amplification": "You can’t pause someone whose watchlist access you don’t have yourself.",
    ]

    public static let letterboxd: [String: String] = [
        "not_allowed": "An admin hasn’t allowed automatic requests from Letterboxd for your account.",
        "invalid_username": "2 to 15 letters, numbers or underscores.",
        "invalid_list_url": "Paste a Letterboxd list address, like letterboxd.com/name/list/best-of-2026/.",
        "limit_reached": "You’ve reached your limit of linked lists. Remove one to add another.",
        "already_linked": "That one is already linked.",
        "use_watchlist_follow": "That’s your own watchlist. Follow it under My watchlist instead.",
        "source_unreadable": "Couldn’t read that list. Check the address, and that the list is public.",
        "watchlist_unreadable": "That watchlist isn’t public, so fusionha can’t follow it. fusionha can only follow what’s public on Letterboxd.",
        "blocked": "Letterboxd is blocking fusionha right now. Try again later.",
        "unavailable": "Letterboxd didn’t answer. Try again in a few minutes.",
        "rate_limited": "You can try again in a moment.",
        "policy": "Your account can request HD·1080p only.",
        "not_connected": "Connect your Letterboxd profile first.",
        "too_large": "That file is too big. The limit is 1 MB (10 MB for the export ZIP).",
        "too_many_rows": "That file has more than 5,000 rows. Split it and import it in two goes.",
        "invalid_file": "Upload watchlist.csv or the Letterboxd export ZIP.",
        "not_ready": "The preview is still matching. Wait a moment.",
        "already_committed": "This file was already imported.",
        "expired": "This preview expired. Upload the file again.",
        "not_found": "That wasn’t found. Reopen the panel and try again.",
    ]

    /// A Plex watchlist mutation's error.
    public static func plexMessage(for error: Error) -> String {
        if let code = (error as? APIError)?.code, let text = plex[code] { return text }
        return ErrorCopy.message(for: error, fallback: fallback)
    }

    /// A Letterboxd error; `watchlist` turns `source_unreadable` into the
    /// watchlist sentence. A 422 list carries its code in `type`.
    public static func letterboxdMessage(for error: Error, watchlist: Bool = false) -> String {
        let api = error as? APIError
        let code = api?.code ?? api?.validationType
        if code == "source_unreadable" && watchlist, let text = letterboxd["watchlist_unreadable"] { return text }
        if let code, let text = letterboxd[code] { return text }
        return ErrorCopy.message(for: error, fallback: fallback)
    }
}

extension APIError {
    /// A 429's next-allowed moment: `sync_available_at` or `retry_after`.
    public var retryAt: String? {
        guard case .http(429, let body) = self,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let detail = object["detail"] as? [String: Any] else { return nil }
        return (detail["sync_available_at"] as? String) ?? (detail["retry_after"] as? String)
    }

    /// A validation error list's first `type` (`{"detail": [{"type": ...}]}`).
    public var validationType: String? {
        guard case .http(_, let body) = self,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let list = object["detail"] as? [[String: Any]] else { return nil }
        return list.first?["type"] as? String
    }
}
