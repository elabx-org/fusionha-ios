import Foundation

/// Plain-English copy for the server's coded refusals.
///
/// fusionha's coded errors arrive as `{"detail": {"code": "...", "detail": "..."}}`.
/// The inner `detail` is server prose and is never shown: the `code` maps to
/// these sentences instead, the same table as the web
/// (`frontend/src/lib/api/requests/errors.ts`), with per-surface overrides for
/// codes the server reuses. Unknown codes fall back to `generic`.
public enum ErrorCopy {
    public static let generic = "Something went wrong. Please try again."

    /// `REQUEST_ERROR_COPY` (requests, issues, threads, policy) plus the
    /// sign-in and secrets codes every client can meet.
    public static let messages: [String: String] = [
        "quota": "You’ve used all your requests for this week.",
        "already_tracked": "Already in your library",
        "already_available": "Already in your library",
        "own_open_request": "You’ve already requested this.",
        "not_joinable": "There’s no open request to join any more.",
        "not_a_joiner": "You’re no longer part of this request.",
        "withdrawn": "This request was withdrawn.",
        "not_rejectable": "This request has already been decided.",
        "not_withdrawable": "This request can’t be withdrawn any more.",
        "own_request": "You can’t decide your own request.",
        "not_allowed": "You don’t have permission to do that.",
        "user_inactive": "This account is disabled.",
        "user_merged": "This account was merged into another one.",
        "user_not_found": "That user no longer exists.",
        "amplification": "You can’t give anyone more than you have yourself.",
        "guard_admin_only": "Only an admin can turn off, delete or loosen a guard.",
        "invalid_rule": "That rule isn’t valid. Check its settings and try again.",
        "invalid_order": "The rules changed while you were reordering. Refresh and try again.",
        "locked": "A built-in rule can only be turned on or off.",
        "scope": "This isn’t available to you.",
        "version_required": "Pick which version has the problem.",
        "not_enabled": "This fix isn’t turned on for you.",
        "needs_decypharr": "Automatic file checks need fusionha’s decypharr build.",
        "rate_limited": "You’ve used your fixes for now. They come back over the next 24 hours.",
        "not_open": "This report has already moved on.",
        "choice_unavailable": "That fix doesn’t apply here any more.",
        "staged_choice": "Choose what to do with the new copy first.",
        "invalid": "That doesn’t look right. Check it and try again.",
        "empty": "Write a message first.",
        "limit": "That message is too long. Shorten it and try again.",
        "bad_cursor": "The list changed. Pull to refresh.",
        // Sign-in limiter and secrets at rest (fusionha requests phase 8).
        "login_rate_limited": "Too many sign-in attempts. Wait a few minutes, then try again.",
        "reauth_rate_limited": "Too many attempts. Wait a few minutes, then try again.",
        "reauth_required": "Enter your password again to continue.",
        "secrets_locked": "The server’s secrets are locked. An admin needs to unlock them on the server.",
        "placeholder_unresolved": "That field has no saved value to keep. Enter it again.",
        // Library.
        "tmdb_not_configured": "Adding needs a TMDB key. Add one in Settings › Metadata.",
        // Queue: finishing a held download (fusionha 0.4.190, `queue-finish.ts`).
        "rows_open": "Some files still need a choice. Pick Current or This file for each one.",
        "not_held": "This download isn’t waiting on you any more. Refresh the queue.",
        "finish_in_progress": "This download is already being finished. Refresh the queue in a moment.",
        "db_busy": "The database is busy. Try again in a moment.",
    ]

    /// Per-surface wording for codes the server reuses (`ISSUE_ERROR_OVERRIDES`).
    public enum Surface: Sendable {
        case filing, window, missingSearch, fix, message

        var overrides: [String: String] {
            switch self {
            case .filing: return [
                "rate_limited": "You’ve reported a lot recently. Try again later.",
                "not_open": "Something changed while you were reporting. Try again.",
            ]
            case .window: return ["rate_limited": "Give it a few minutes before trying again."]
            case .missingSearch: return [
                "rate_limited": "We searched for this recently. Try again in a little while.",
                "not_allowed": "You don’t have permission for this fix.",
            ]
            case .fix: return ["not_allowed": "You don’t have permission for this fix."]
            case .message: return [
                "rate_limited": "You’ve sent a lot of messages. Try again in a bit.",
                "invalid": "Pick who this message is for.",
            ]
            }
        }
    }

    /// The surface for an issue fix action (`issueActionOverrides` on the web).
    public static func surface(forIssueAction action: String) -> [Surface] {
        switch action {
        case "search_missing": return [.missingSearch]
        case "plex_rescan": return [.window, .fix]
        default: return [.fix]
        }
    }

    /// The sentence for a code, or nil when it isn't one we know.
    public static func message(code: String, surfaces: [Surface] = []) -> String? {
        for surface in surfaces { if let text = surface.overrides[code] { return text } }
        return messages[code]
    }

    /// The sentence to show for any error: known codes get their copy, coded
    /// but unknown errors get `fallback` (never the server's inner prose),
    /// anything else its own description.
    public static func message(for error: Error, fallback: String = generic, surfaces: [Surface] = []) -> String {
        guard let api = error as? APIError else { return error.localizedDescription }
        if let code = api.code { return message(code: code, surfaces: surfaces) ?? fallback }
        return api.errorDescription ?? fallback
    }
}

extension APIError {
    /// The `detail.code` of a coded refusal (`{"detail": {"code": ...}}`), else nil.
    public var code: String? {
        guard case .http(_, let body) = self,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let detail = object["detail"] as? [String: Any] else { return nil }
        return detail["code"] as? String
    }
}
