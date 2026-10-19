import SwiftUI
import FusionhaKit

// MARK: - Dialogs (components/activity)

struct RemoveQueueDialog: View {
    let item: QueueItem
    let offerSearch: Bool
    let onConfirm: (_ deleteData: Bool, _ blocklist: Bool, _ search: Bool) -> Void
    let onCancel: () -> Void
    @State private var deleteFile = true
    @State private var blocklist = false
    @State private var search = false

    var body: some View {
        let hasFile = item.hasDownloadedFile == true
        let parts = [hasFile && deleteFile ? "delete file" : nil, blocklist ? "blocklist" : nil,
                     (offerSearch || blocklist) && search ? "search" : nil].compactMap { $0 }
        ActDialog(title: "Remove from queue?",
                  message: "\(item.title) will be removed from the download queue.",
                  confirmLabel: parts.isEmpty ? "Remove" : "Remove and " + parts.joined(separator: " and "),
                  onCancel: onCancel,
                  onConfirm: { onConfirm(hasFile && deleteFile, blocklist, (offerSearch || blocklist) && search) }) {
            if hasFile {
                ActOption(label: "Also delete the downloaded file from disk", isOn: $deleteFile)
            }
            ActOption(label: "Also blocklist this release", hint: "Off by default — it permanently disqualifies the release.",
                      isOn: $blocklist)
                .onChange(of: blocklist) { if blocklist { search = true } }
            if offerSearch || blocklist {
                ActOption(label: "Also search for a replacement", hint: "Kicks a fresh search once this download is gone.", isOn: $search)
            }
        }
    }
}

/// One download listed in a group's "Remove all" confirm.
struct BulkRemoveEntry: Hashable {
    let label: String
    let size: Double
}

struct BulkRemoveDialog: View {
    let count: Int
    let fileCount: Int
    /// When given, the confirm lists every download and the total size.
    var entries: [BulkRemoveEntry] = []
    let defaultBlocklist: Bool
    let busy: Bool
    let onConfirm: (_ deleteFiles: Bool, _ blocklist: Bool) -> Void
    let onCancel: () -> Void
    @State private var deleteFiles = false
    @State private var blocklist = false

    var body: some View {
        let parts = [deleteFiles && fileCount > 0 ? "delete files" : nil, blocklist ? "blocklist" : nil].compactMap { $0 }
        ActDialog(title: "Remove \(ActFmt.plural(count, "download")) from queue?",
                  message: "The selected download\(count == 1 ? "" : "s") will be removed from the download queue.",
                  confirmLabel: parts.isEmpty ? "Remove \(count)" : "Remove and " + parts.joined(separator: " and "),
                  busy: busy, onCancel: onCancel,
                  onConfirm: { onConfirm(deleteFiles && fileCount > 0, blocklist) }) {
            if !entries.isEmpty { entryList }
            if fileCount > 0 {
                ActOption(label: "Also delete the downloaded file\(count == 1 ? "" : "s") from disk (\(fileCount) of \(count) on disk)",
                          isOn: $deleteFiles)
            }
            ActOption(label: "Also blocklist these releases", hint: "Off by default — it permanently disqualifies the releases.",
                      isOn: $blocklist)
        }
        // Pre-ticked only when every row has a file on disk (web BulkRemoveDialog).
        .onAppear { blocklist = defaultBlocklist; deleteFiles = fileCount > 0 && fileCount >= count }
    }

    /// "4 downloads · 4.7 GB total", then each download and its size.
    private var entryList: some View {
        let total = entries.reduce(0) { $0 + max(0, $1.size) }
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(ActFmt.plural(entries.count, "download")) · \(ActFmt.bytes(total)) total")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 8) {
                            Text(entry.label).font(.system(size: 13)).foregroundStyle(Theme.txt).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(ActFmt.bytes(entry.size)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.mut)
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding(10)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
