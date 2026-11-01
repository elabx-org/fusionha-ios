import SwiftUI
import FusionhaKit

/// The open Duo's right page in a held scan with nothing ticked and no file
/// opened (web `NothingSelectedPanel`, the bulk-decide mock's nothing-selected
/// state): how to start, and one tap to tick everything undecided. Solid
/// content on the page.
struct MINothingSelectedPanel: View {
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing selected")
                .font(.headline)
                .foregroundStyle(Theme.txt)
                .accessibilityAddTraits(.isHeader)
            Text("Tick files on the left to decide them together, or open one to compare.")
                .font(.subheadline)
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            MISelectUndecidedButton(showsCount: true)
                .buttonStyle(ActButtonStyle(kind: .ghost))
                .disabled(session.bulkBusy || session.working)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
