import SwiftUI
import FusionhaKit

/// Manage episodes' bar (mock column): close, Re-scan, and the select
/// button, which selects every file and, once anything is selected, fills
/// with the accent and clears the selection.
struct V2ManageToolbar: ToolbarContent {
    let model: ManageFilesModel
    let enabled: Bool
    let close: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark", action: close)
                .closeOnEscape(true)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            ToolbarActionButton(title: "Re-scan", systemImage: "arrow.clockwise", busy: model.rescanning) {
                Task { await model.rescan() }
            }
            .disabled(!enabled)
            if model.selected.isEmpty {
                Button("Select all", systemImage: "checkmark") { model.toggleAll() }
                    .disabled(!enabled || model.items.isEmpty)
            } else {
                Button("Clear selection", systemImage: "checkmark") { model.selected = [] }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.primary)
                    .disabled(!enabled)
            }
        }
    }
}

/// The row menu's Replace / Clean up answers (v1's dialog words).
struct V2ManageRowConfirmButtons: View {
    let model: ManageFilesModel
    let confirm: ManageFilesConfirm

    var body: some View {
        switch confirm {
        case .delete(let items):
            Button(items.count == 1 ? "Delete file" : "Delete \(items.count) files", role: .destructive) {
                Task { await model.delete(items) }
            }
        case .replace(let items):
            Button(items.count == 1 && items[0].unreadable ? "Replace anyway" : "Replace", role: .destructive) {
                Task { await model.replace(items) }
            }
        case .cleanup(let items):
            Button("Clean up", role: .destructive) { Task { await model.cleanup(items) } }
        }
        Button("Cancel", role: .cancel) {}
    }
}
