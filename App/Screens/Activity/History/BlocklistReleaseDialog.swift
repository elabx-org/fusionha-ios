import SwiftUI
import FusionhaKit

/// The caret's "Blocklist this release?" dialog.
struct BlocklistReleaseDialog: View {
    let release: String
    /// A HELD row: the hold kept the current file, so deleting it is never offered.
    var keepsCurrentFile = false
    let onConfirm: (_ search: Bool, _ deleteFile: Bool) -> Void
    let onCancel: () -> Void
    @State private var search = true
    @State private var deleteFile = false

    private var confirmLabel: String {
        switch (deleteFile, search) {
        case (false, false): return "Blocklist"
        case (false, true): return "Blocklist and search"
        case (true, false): return "Blocklist & delete"
        case (true, true): return "Blocklist, delete & search"
        }
    }

    var body: some View {
        ActDialog(title: "Blocklist this release?",
                  message: "\(release) will never be grabbed again for this version.",
                  confirmLabel: confirmLabel, onCancel: onCancel, onConfirm: { onConfirm(search, deleteFile && !keepsCurrentFile) }) {
            ActOption(label: "Also search for a replacement", isOn: $search)
            if !keepsCurrentFile {
                ActOption(label: "Delete the current file",
                          hint: "Needed to replace a file that already scores well — a search alone won’t beat it.",
                          isOn: $deleteFile)
            }
        }
    }
}
