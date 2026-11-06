import SwiftUI
import FusionhaKit

/// "Block <GROUP>?" from a row's menu (interactive search, Files, History):
/// the block form for that one group, this title unless "Everywhere" is
/// on. Rows of the group stay where they are, shown as blocked.
struct V2BlockGroupSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: GroupBlockTarget
    let title: String
    /// Says it worked where the sheet was opened; the title page's toast by default.
    var onBlocked: ((String) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Stop grabbing releases from \(target.group). Rows from it stay in lists, marked Blocked group.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                    V2BlockGroupForm(title: title, fixedGroup: target.group) { group, everywhere in
                        let line = HeldCopy.scopeLabel(everywhere ? .global : .item, group: group, title: title)
                        if let onBlocked { onBlocked(line) } else {
                            store.show(line, title: "Release group blocked", variant: .success)
                        }
                        dismiss()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Block \(target.group)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: "Close") { dismiss() }
                }
            }
            .task { if store.groupBlocks == nil { await store.loadGroupBlocks() } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
