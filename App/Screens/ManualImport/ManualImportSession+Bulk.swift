import SwiftUI
import FusionhaKit

/// Batch writes over several rows (the web's `useFanOut`): bulk edit, Confirm
/// a medium match, and Keep current / Import anyway for rows that are not an
/// upgrade. Each row is its own override, sent one at a time.
extension ManualImportSession {

    /// Sets the same fields on every uncommitted row (Edit all / Edit N selected).
    func bulkPatch(_ targets: [ManualImportRow], _ fields: [String: SettingsJSON]) async {
        await fanOut(targets.filter { !$0.committed }) { row in fields }
    }

    /// Vouches for each row's own matched title.
    func confirm(_ targets: [ManualImportRow]) async {
        await fanOut(targets.filter(ManualImportBatch.confirmEligible)) { row in
            ["item_id": .optional(row.match.itemId)]
        }
    }

    /// Keep current or Import anyway over the not-an-upgrade rows; Import anyway
    /// is bound to each row's file on screen by `patch`.
    func decideNotAnUpgrade(_ targets: [ManualImportRow], choice: String) async {
        await fanOut(targets.filter(ManualImportBatch.replaceEligible)) { _ in
            ["replace_choice": .string(choice)]
        }
    }

    private func fanOut(_ targets: [ManualImportRow], _ body: (ManualImportRow) -> [String: SettingsJSON]) async {
        guard !targets.isEmpty else { return }
        bulkBusy = true
        defer { bulkBusy = false }
        for row in targets {
            // Each write lands on the row as it is now.
            let live = rows.first { $0.rowId == row.rowId } ?? row
            await patch(live, body(live))
        }
    }
}
