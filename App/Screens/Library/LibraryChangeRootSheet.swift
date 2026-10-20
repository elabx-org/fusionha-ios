import SwiftUI
import FusionhaKit

/// ChangeRootPopover: re-assign the selection's root folder per tier.
struct ChangeRootSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// HD·1080p by default: "Every version" collapses the tiers onto one root.
    @State private var tier = "HD-1080p"
    @State private var roots: [RootFolder] = []
    @State private var rootId: Int?
    @State private var disposition: RootFileDisposition = .move

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Re-assign root folder").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
            field("Which versions to move") {
                SegmentedPills(options: [("HD-1080p", "HD·1080p"), ("UHD-2160p", "UHD·4K"), ("all", "Every version")],
                               selection: $tier, fill: true)
                if tier == "all" {
                    warning("This collapses HD·1080p, UHD·4K and every edition onto one root, so the tier separation is lost. Prefer scoping to one tier.", Theme.miss)
                }
            }
            field("New root folder") {
                Picker("New root folder", selection: $rootId) {
                    Text("Choose…").tag(Int?.none)
                    ForEach(roots) { Text($0.path).tag(Int?.some($0.id)) }
                }
                .pickerStyle(.menu)
                .tint(Theme.txt)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .panel(Theme.panel2, radius: 10)
            }
            field("Existing files") {
                SegmentedPills(options: RootFileDisposition.allCases.map { ($0, $0.label) }, selection: $disposition, fill: true)
                if disposition == .delete {
                    warning("The existing files are permanently deleted.", Theme.danger)
                } else if disposition == .leave {
                    warning("Files stay in the old folder. Those versions show as Missing until moved or re-imported.", Theme.miss)
                }
            }
            Spacer(minLength: 0)
            Button {
                guard let rootId else { return }
                let tier = self.tier, disposition = self.disposition
                model.bulk("Root folder updated", "Couldn't change the root folder") { client, ids in
                    try await client.bulkRootFolder(BulkRootFolderRequest(itemIds: ids, tier: tier, rootFolderId: rootId,
                                                                          disposition: disposition))
                }
                dismiss()
            } label: {
                Text("Apply")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.primary, in: Capsule())
            }
            .buttonStyle(PressScaleStyle())
            .disabled(rootId == nil)
            .opacity(rootId == nil ? 0.5 : 1)
        }
        .padding(20)
        .task { roots = (try? await model.client?.rootFolders()) ?? [] }
    }

    private func warning(_ text: String, _ tone: Color) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.txt)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .actWash(tone, radius: 10, base: Theme.panel2)
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
            content()
        }
    }
}
