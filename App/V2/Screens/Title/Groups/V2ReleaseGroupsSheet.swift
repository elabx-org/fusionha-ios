import SwiftUI
import FusionhaKit

/// Title › More › Release groups: the groups blocked for this title, then
/// the global blocks that apply to it too ("Everywhere"), each with
/// Unblock; then "Block a group" (`V2BlockGroupForm`, this title unless
/// "Everywhere" is on). A sheet folded, a page cover on the open Duo.
struct V2ReleaseGroupsSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail
    @State private var removing: Set<Int> = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    blocked
                    V2BlockGroupForm(title: detail.title) { _, _ in error = nil }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Release groups")
            .navigationSubtitle(detail.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: "Close") { dismiss() }
                }
            }
            .task { await store.loadGroupBlocks() }
        }
        .presentationDragIndicator(.visible)
    }

    private var blocked: some View {
        let rows = store.groupBlocks ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Blocked")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if !rows.isEmpty {
                    Text("\(rows.count)").font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, rows.isEmpty ? 6 : 4)
            if store.groupBlocks == nil {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 16)
            } else if rows.isEmpty {
                Text("No release groups are blocked for this title.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.mut)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            } else {
                ForEach(rows) { block in
                    if block.id != rows.first?.id { Divider().padding(.leading, 58) }
                    V2GroupBlockRow(block: block, busy: removing.contains(block.id)) {
                        Task { await unblock(block) }
                    }
                    .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
                .padding(.bottom, 4)
            }
            if let error {
                Text(error)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.dangerText)
                    .padding([.horizontal, .bottom], 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 20) }
        .animation(reduce ? nil : .snappy(duration: 0.25), value: rows.map(\.id))
    }

    private func unblock(_ block: ReleaseGroupBlock) async {
        removing.insert(block.id)
        error = await store.unblockReleaseGroup(block)
        removing.remove(block.id)
    }
}
