import SwiftUI
import FusionhaKit

/// The decision panel's glass chips (open Duo): Import mode (only while
/// Import is possible), Confirm N medium matches and Edit N selected…, the
/// same three the Decide menu holds on the phone and the closed Duo.
struct MIDecideChips: View {
    let summary: ManualImportBulkSummary
    @Binding var editing: Bool
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        @Bindable var session = session
        let confirm = session.tickedToConfirm
        ActFlow(spacing: 8, lineSpacing: 8) {
            if !summary.imp.isEmpty {
                Menu {
                    Picker("Import mode", selection: $session.importMode) {
                        ForEach(ManualImportMode.allCases) { mode in
                            Text("\(mode.label) · \(mode.hint)").tag(mode)
                        }
                    }
                } label: { GlassMenuLabel(title: "Import mode: \(session.importMode.label)") }
                .accessibilityLabel("Import mode, \(session.importMode.label)")
            }
            if !confirm.isEmpty {
                chip("Confirm \(confirm.count) medium match\(confirm.count == 1 ? "" : "es")", "questionmark.diamond") {
                    Task { await session.confirm(confirm) }
                }
            }
            if !summary.open.isEmpty {
                chip("Edit \(summary.open.count) selected…", "pencil") { editing = true }
            }
        }
    }

    private func chip(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassControl()
    }
}
