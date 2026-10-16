import Foundation

/// User copy for every coded refusal of the secrets routes and the backup key
/// path (web `secrets-errors.ts`). Settings › Security never shows a raw
/// server message or code: an unknown code falls back to wording for its status.
public enum SecretsErrorCopy {
    public static let generic = "Something went wrong. Try again."

    static let fixed: [String: String] = [
        "reauth_unavailable": "This sign-in has no password to confirm. Sign in as an admin with a password, or read the key file from the data volume on the server.",
        "reauth_required": "Enter your password to confirm this change.",
        "reauth_plex_mismatch": "That Plex account isn’t the one linked to your fusionha account. Sign in to Plex as the linked account, then try again.",
        "reauth_grant_invalid": "That Plex confirmation has expired or was already used. Confirm with Plex again.",
        "secrets_locked": "Secrets are locked, so this can’t be done yet. Unlock them in Settings → Security first.",
        "rotation_running": "A key rotation is running. Key actions are paused until it finishes. Try again in a moment.",
        "key_from_env": "The key comes from the FUSIONHA_SECRET_KEY setting on the server, so fusionha can’t change it from here. Change it where you set that variable.",
        "not_locked": "Secrets aren’t locked, so there’s nothing to unlock.",
        "key_mismatch": "That key doesn’t match this database. Check you pasted the recovery key for this install, or the contents of its key file.",
        "no_key_location": "fusionha has nowhere to save a key file. Mount a data volume or set a key file path, then try again.",
        "key_file_unreadable": "fusionha can’t read the key file. Check its permissions on the data volume, then try again.",
        "unlock_unverifiable": "Nothing stored here can confirm a key, so fusionha can’t tell whether this one is right. Use Start over to set a new key.",
        "not_unreadable": "One of those secrets can be read after all, so it was left as it is. Refresh and try again.",
        "not_rotating": "There’s no key rotation waiting to finish.",
        "secret_unreadable": "That value was encrypted with a key fusionha doesn’t have, so it can’t be changed yet. Reset it in Settings → Security first.",
        "key_text_too_large": "That’s too much text for a recovery key. Paste only the key, or the contents of the key file.",
        "invalid": "Some of what you entered isn’t valid. Check it and try again.",
        "confirm_required": "Type START OVER exactly to confirm.",
        "backup_folder_unsafe": "Backups can’t go in that folder. The app serves files from it, or an update replaces it. Choose a folder on a mounted volume, such as /data/backups.",
        "reauth_rate_limited": "Too many wrong passwords. Wait 15 minutes, then try again.",
        "login_rate_limited": "Too many failed sign-ins. Wait 15 minutes, then try again.",
        "key_file_error": "fusionha couldn’t write the key file. Check the data volume is writable and has space. Any key that was replaced is archived next to it.",
        "rotation_not_started": "The rotation didn’t start, and nothing was changed. Try again.",
        "rotation_not_recorded": "The new key is in place, but fusionha couldn’t record the rotation. Resume it, or restart fusionha.",
        "fingerprint_not_recorded": "The new key was saved, but fusionha couldn’t record it, so secrets stay locked. Your previous key is archived next to the key file. Try again.",
    ]

    static let byStatus: [Int: String] = [
        401: "Your session has ended. Sign in again.",
        403: "You don’t have permission to do that.",
        404: "That item isn’t there any more. Refresh and try again.",
        409: "That can’t be done in the current state. Refresh and try again.",
        413: "That’s too much text to accept.",
        422: "Some of what you entered isn’t valid. Check it and try again.",
        429: "Too many tries. Wait a few minutes, then try again.",
    ]

    /// The sentence for a coded refusal, weaving in the key path where the web does.
    public static func message(code: String, keyPath: String? = nil) -> String? {
        switch code {
        case "bad_password":
            return "That password is wrong."
        case "reauth_too_new":
            let path = keyPath.map { ": \($0)" } ?? ""
            return "The key can’t be shown yet. For safety, an admin whose access or password changed in the last 24 hours has to wait before revealing the key. Try again later. If you need it sooner, copy the key file from the server\(path)."
        case "key_file_exists":
            let place = keyPath.map { "at \($0)" } ?? "in place"
            return "A key file is already \(place), so fusionha left it alone. Nothing was changed. Move it aside first if you mean to replace it."
        case "placeholder_unresolved":
            return "That field has no saved value to keep. Enter a value."
        default:
            return fixed[code]
        }
    }

    /// Plain wording for any error from a secrets call.
    public static func message(for error: Error, keyPath: String? = nil) -> String {
        guard let api = error as? APIError else { return generic }
        if let code = api.code, let text = message(code: code, keyPath: keyPath) { return text }
        if case .http(let status, _) = api {
            if status >= 500 { return generic }
            return byStatus[status] ?? generic
        }
        return api.errorDescription ?? generic
    }

    /// The 24 h wait: the password field is replaced by the note.
    public static func isTooNew(_ error: Error?) -> Bool {
        (error as? APIError)?.code == "reauth_too_new"
    }

    /// The 24 h note split into its bold first sentence and the rest.
    public static func split(_ text: String) -> (head: String, rest: String) {
        guard let r = text.range(of: ". ") else { return (text, "") }
        return (String(text[..<r.lowerBound]) + ".", String(text[r.upperBound...]))
    }
}
