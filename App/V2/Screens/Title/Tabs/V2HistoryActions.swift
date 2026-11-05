import Foundation
import FusionhaKit

/// The History tab's row actions on the title's store, so they toast on the
/// page like every other title action. Blocklist is the Activity History's
/// one-tap blocklist (`ActActions.blocklist`: `POST /api/v1/blocklist` with a
/// replacement search, Undo while it deleted no file); Regrab is v1's
/// `DetailStore.regrab`.
extension DetailStore {
    func blocklist(_ entry: HistoryEntry) async {
        guard let client, let target = entry.blocklistTarget else { return }
        do {
            let result = try await client.blocklistRelease(target.body(search: true, deleteFile: false))
            let searching = result.searchDispatched == true
            let message: String
            if result.fileDeleted == true {
                message = searching ? "Blocklisted, deleted the file, and searching for a replacement" : "Blocklisted and deleted the file"
            } else if result.created {
                message = searching ? "Blocklisted — searching for a replacement" : "Release blocklisted"
            } else {
                message = searching ? "Already blocklisted — searching for a replacement" : "Already blocklisted"
            }
            let variant: DetailToast.Variant = result.created || searching ? .success : .warning
            if result.created, result.fileDeleted != true, let id = result.entry?.id {
                show(message, variant: variant, actionLabel: "Undo") { [weak self] in
                    Task { await self?.unblock(id) }
                }
            } else {
                show(message, variant: variant)
            }
            await reload()
        } catch let error as APIError where error.status == 422 || error.status == 404 {
            show(error.serverDetail ?? "Couldn't blocklist this release — try again", variant: .warning)
        } catch {
            show("Couldn't blocklist this release — try again", variant: .error)
        }
    }

    private func unblock(_ id: Int) async {
        guard let client else { return }
        do {
            try await client.deleteBlocklistEntry(id: id)
            show("Blocklist cleared", variant: .success)
            await reload()
        } catch {
            show("Couldn't clear the blocklist entry", variant: .error)
        }
    }
}

/// What the History rows read off an event.
enum V2HistoryEvent {
    static let failures: Set<String> = ["DOWNLOAD_FAILED", "GRAB_FAILED", "FILE_MOVE_FAILED"]

    static func isFailure(_ entry: HistoryEntry) -> Bool { failures.contains(entry.eventType) }

    /// The failure's reason in words (`FailureCopy`), or a hold's text.
    static func reason(_ entry: HistoryEntry) -> String? {
        if let held = entry.held, !held.text.isEmpty { return held.text }
        guard isFailure(entry) else { return nil }
        let raw = entry.data?.text("error") ?? entry.data?.text("reason") ?? entry.data?.text("message")
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return FailureCopy.format(raw, context: .download).detail
    }

    /// The grab to re-send for a row: the row itself when it is a grab, else
    /// the grab of the same download (a failure carries no release to resend).
    static func regrabEntry(_ entry: HistoryEntry, in history: [HistoryEntry]) -> HistoryEntry? {
        if entry.eventType == "GRABBED" { return entry }
        guard let download = entry.downloadId, !download.isEmpty else { return nil }
        return history.first { $0.eventType == "GRABBED" && $0.downloadId == download }
    }

    /// The version chip's state: an outline for what failed or was removed,
    /// orange for a hold, filled otherwise (mock `evRow`).
    static func badgeState(_ entry: HistoryEntry) -> EditionBadgeState {
        switch entry.eventType {
        case "HELD", "NEEDS_ATTENTION": return .held
        case "DELETED": return .missing
        default: return isFailure(entry) ? .missing : .onDisk
        }
    }

    /// `+6,125` / `-300`.
    static func score(_ value: Int) -> String {
        (value > 0 ? "+" : "") + value.formatted()
    }

    /// The day header: Today, Yesterday, then "Wed 28 Oct".
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
