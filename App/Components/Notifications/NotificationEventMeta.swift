import SwiftUI
import FusionhaKit

/// One event kind's row copy (web `notification-events.ts`, the approved A10
/// mock's KIND_META verbatim) and its category colour.
struct NotificationEventMeta {
    let label: String
    let hint: String
    let sev: Color

    /// Shown under the retired `issue_reported` kind (read-only, off).
    static let retiredHint = "Retired · replaced by Issue needs you"

    /// Kinds introduced in phase 3 (get the "New" pill).
    static let newKinds: Set<String> = [
        "issue_auto_fixed", "self_service_action", "issue_needs_you", "request_update", "issue_update",
    ]

    /// Copy for a kind; a kind newer than this build falls back to its humanised name.
    static func of(_ kind: String) -> NotificationEventMeta {
        switch kind {
        case "grab": .init(label: "Grabbed", hint: "A release was sent to the download client", sev: Theme.grab)
        case "import": .init(label: "Imported", hint: "A file was imported into the library", sev: Theme.done)
        case "upgrade": .init(label: "Upgrade found", hint: "A better release replaced an existing file", sev: Theme.grab)
        case "manual_required": .init(label: "Manual import required",
                                      hint: "A finished download is waiting for you to pick the file", sev: Theme.miss)
        case "failed": .init(label: "Download failed", hint: "A grab or import failed", sev: Theme.danger)
        case "needs_attention": .init(label: "Needs attention", hint: "A manual import or a stuck item needs you",
                                      sev: Theme.miss)
        case "issue_reported": .init(label: "Issue reported", hint: retiredHint, sev: Theme.dim)
        case "retargeted": .init(label: "Re-routed",
                                 hint: "An imported file was moved to the version that matches its real resolution",
                                 sev: Theme.premiere)
        case "request_available": .init(label: "Request available", hint: "A title someone requested is now downloaded",
                                        sev: Theme.anime)
        case "request_made": .init(label: "New request", hint: "A user submitted a new media request", sev: Theme.anime)
        case "request_update": .init(label: "Request update",
                                     hint: "An approver approved, declined or changed one of your requests",
                                     sev: Theme.anime)
        case "issue_update": .init(label: "Issue update", hint: "An issue you reported or joined was resolved",
                                   sev: Theme.anime)
        case "issue_auto_fixed": .init(label: "Issue auto-fixed",
                                       hint: "fusionha confirmed a problem and repaired it (dead copy, missing episodes, Plex rescan)",
                                       sev: Theme.done)
        case "self_service_action": .init(label: "Self-service action taken",
                                          hint: "A user started a fix themselves: a search, a rescan or a version request",
                                          sev: Theme.grab)
        case "issue_needs_you": .init(label: "Issue needs you",
                                      hint: "Inconclusive check, a fix that failed twice, or a report from a client without checks",
                                      sev: Theme.miss)
        default:
            .init(label: kind.replacingOccurrences(of: "_", with: " ").capitalizingFirst, hint: "", sev: Theme.dim)
        }
    }

    /// Friendly copy for a failed preference write (web `deliveryErrorCopy`);
    /// never the raw server text.
    static func writeError(_ error: Error) -> String {
        let code = (error as? APIError)?.code
        switch code {
        case "retired_kind": return "That notification has been retired and can no longer be changed."
        case "not_a_recipient": return "You don't receive this kind of notification."
        case "digest_not_supported": return "This notification can't be sent as a daily digest."
        default: return "Couldn't save that change. Try again."
        }
    }
}

private extension String {
    var capitalizingFirst: String { prefix(1).uppercased() + dropFirst() }
}
