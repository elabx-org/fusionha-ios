import SwiftUI

/// The bar's More menu (plan S8): Process queue now, Select (or Done), and
/// Clear queue, which says why it is unavailable while a search or later
/// pages hide part of the queue.
struct V2QueueMoreMenu: View {
    let processing: Bool
    let selecting: Bool
    let canClear: Bool
    let isEmpty: Bool
    let process: () -> Void
    let toggleSelect: () -> Void
    let clear: () -> Void

    var body: some View {
        Menu {
            Button(processing ? "Processing…" : "Process queue now", systemImage: "arrow.clockwise", action: process)
                .disabled(processing)
            Button(selecting ? "Done selecting" : "Select", systemImage: selecting ? "xmark" : "checkmark.circle",
                   action: toggleSelect)
                .disabled(isEmpty && !selecting)
            Divider()
            Button("Clear queue…", systemImage: "trash", role: .destructive, action: clear)
                .disabled(!canClear || isEmpty)
            if !canClear && !isEmpty {
                Text("Clear the search and load every page to clear the queue")
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .accessibilityLabel("More: process queue, select, clear")
    }
}
