import SwiftUI
import FusionhaKit

/// "N selected · Actions" (the web's `SelectionActionsSheet`): decide a batch at
/// once. Selected files that are not an upgrade get Keep current / Import
/// anyway; medium matches can be confirmed; the selection can be widened,
/// narrowed or bulk-edited. Only files that are ready import.
struct MISelectionSheet: View {
    @Environment(ManualImportSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false

    private var visible: [ManualImportRow] { session.rows.filter(session.filter.matches) }
    private var picked: [ManualImportRow] { session.rows.filter { session.selected.contains($0.rowId) } }

    var body: some View {
        let picked = picked
        let notUp = ManualImportBatch.notAnUpgrade(session.rows, selected: session.selected)
        let toConfirm = picked.filter(ManualImportBatch.confirmEligible)
        let pickable = visible.filter(ManualImportBatch.isPickable)
        let ready = visible.filter(ManualImportRules.isImportable)
        let busy = session.bulkBusy || session.working
        NavigationStack {
            List {
                if !notUp.isEmpty {
                    Section("\(notUp.count) selected \(notUp.count == 1 ? "is" : "are") not an upgrade") {
                        HStack(spacing: 8) {
                            decide("Keep current", "internaldrive", notUp, choice: "keep_current")
                            decide("Import anyway", "arrow.down", notUp, choice: "import")
                        }
                        .disabled(busy)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                Section {
                    if !toConfirm.isEmpty {
                        Button("Confirm \(toConfirm.count) medium match\(toConfirm.count == 1 ? "" : "es")", systemImage: "questionmark.diamond") {
                            run { await session.confirm(toConfirm) }
                        }
                        .foregroundStyle(Theme.accentText)
                        .disabled(busy)
                    }
                    action("Select all", count: pickable.count) {
                        session.selected.formUnion(pickable.map(\.rowId))
                    }
                    action("Select all ready", count: ready.count) {
                        session.selected = Set(ready.map(\.rowId))
                    }
                    .disabled(ready.isEmpty)
                    Button("Clear selection") { session.selected = []; dismiss() }
                        .foregroundStyle(Theme.txt)
                        .disabled(picked.isEmpty)
                    Button { editing = true } label: {
                        LabeledContent("Edit \(picked.count) selected…") { Image(systemName: "chevron.right").foregroundStyle(Theme.dim) }
                    }
                    .foregroundStyle(Theme.txt)
                    .disabled(picked.isEmpty)
                } footer: {
                    Text("Any file can be selected, so you can decide a batch at once. Only files that are ready import.")
                }
            }
            .navigationTitle("\(picked.count) selected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } } }
            .navigationDestination(isPresented: $editing) {
                MIBulkSheet(title: "Edit \(picked.count) selected", rows: picked.filter { !$0.committed }, embedded: true)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func decide(_ label: String, _ icon: String, _ rows: [ManualImportRow], choice: String) -> some View {
        Button { run { await session.decideNotAnUpgrade(rows, choice: choice) } } label: {
            Label(label, systemImage: icon).frame(maxWidth: .infinity)
        }
        .buttonStyle(ActButtonStyle(kind: .subtle))
    }

    private func action(_ label: String, count: Int, _ apply: @escaping () -> Void) -> some View {
        Button { apply(); dismiss() } label: {
            LabeledContent(label) { Text("\(count)").monospacedDigit().foregroundStyle(Theme.mut) }
        }
        .foregroundStyle(Theme.txt)
    }

    private func run(_ work: @escaping @MainActor () async -> Void) {
        Task {
            await work()
            dismiss()
        }
    }
}
