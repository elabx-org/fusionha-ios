import SwiftUI
import FusionhaKit

/// "Replace your copy?" (fusionha 0.4.233 B1, the web's `ReplaceConfirm`): an
/// import that would replace a copy that is as good or better asks inline on
/// its row first, with the one-line compare. Replace sends Import anyway bound
/// to that copy; Keep it goes back to the row's choices. Never an alert.
struct MIReplaceConfirm: View {
    let row: ManualImportRow
    let text: String
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        let busy = session.busyRows.contains(row.rowId) || session.working
        VStack(alignment: .leading, spacing: 8) {
            Label(text, systemImage: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ActAsyncButton(label: "Replace", systemImage: "arrow.triangle.2.circlepath", kind: .danger) {
                    await session.replaceRow(row)
                    return session.rowErrors[row.rowId] == nil
                }
                .fixedSize()
                Button("Keep it") { session.confirming[row.rowId] = nil }
                    .buttonStyle(ActButtonStyle(kind: .subtle))
                    .fixedSize()
            }
            .disabled(busy)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.miss.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous).strokeBorder(Theme.miss.opacity(0.35)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Replace your current copy?")
    }
}
