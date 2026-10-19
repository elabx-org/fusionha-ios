import SwiftUI
import FusionhaKit

/// The HELD step's body (web `HeldStep`, mock B): Downloaded / Probed /
/// Blocklisted / Group lines, the persist note, and "Block <group>…" — offered
/// only for a proven fake with no block in force, when the server's evidence
/// says to prompt.
struct LifecycleHeldStep: View {
    let event: HistoryEntry
    let data: HeldEventData
    let itemTitle: String
    let groupBlock: ReleaseGroupBlock?
    @Environment(AppModel.self) private var model
    @State private var shouldPrompt = false
    @State private var blocking = false

    private var group: String? { data.releaseGroup.flatMap { $0.isEmpty ? nil : $0 } }
    private var mayManage: Bool { model.me?.hasPermission("integrations.manage") == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let size = data.downloadSize, let client = event.downloadClient {
                line("Downloaded · \(client) · \(ActFmt.bytes(size))")
            }
            if let probed = data.probedLine { line(probed) }
            if data.releaseBlocklisted {
                line(data.isProvenMislabel ? "Blocklisted: this release · mislabelled resolution" : "Blocklisted: this release")
            }
            if let groupBlock, let group {
                (Text(groupBlock.scope == "global" ? "Group \(group): skipped everywhere"
                      : "Group \(group): skipped for \(groupBlock.itemTitle ?? "this title")")
                 + Text(" · current setting").foregroundColor(Theme.dim))
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            (Text("This entry is written before the queue row is removed.").bold()
             + Text(" Removing the download later does not erase it."))
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 2)
            if canBlock, let group {
                Button { blocking = true } label: {
                    Label("Block \(group)…", systemImage: "nosign")
                }
                .buttonStyle(ActButtonStyle(kind: .danger))
                .padding(.top, 4)
            }
        }
        .task(id: event.id) { await loadEvidence() }
        .sheet(isPresented: $blocking) {
            if let group, let itemId = event.mediaItemId {
                BlockReleaseGroupSheet(group: group, mediaItemId: itemId, title: itemTitle,
                                       claimedResolution: data.claimedResolution)
            }
        }
    }

    private var canBlock: Bool {
        data.isProvenMislabel && mayManage && group != nil && data.probedResolution != nil
            && data.claimedResolution != nil && event.mediaItemId != nil && groupBlock == nil && shouldPrompt
    }

    private func line(_ text: String) -> some View {
        Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
    }

    private func loadEvidence() async {
        guard data.isProvenMislabel, mayManage, groupBlock == nil, let group, let itemId = event.mediaItemId,
              let evidence = try? await model.client?.releaseGroupEvidence(group: group, mediaItemId: itemId) else { return }
        shouldPrompt = evidence.prompt.shouldPrompt
    }
}
