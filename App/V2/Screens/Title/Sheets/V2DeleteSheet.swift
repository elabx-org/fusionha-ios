import SwiftUI
import FusionhaKit

/// Delete a title (mock browse-sheets.js `deleteBody`): what goes, said
/// exactly. Each version's folder with its file count and size, then
/// "Also delete the files" (off unless switched on, with the total), then
/// the red Delete and Cancel. It calls v1's `DetailStore.deleteItem`.
struct V2DeleteSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail
    @State private var deleteFiles = false
    @State private var busy = false

    private var noun: String { detail.isSeries ? "series" : "movie" }
    private var fileCount: Int { detail.orderedEditions.reduce(0) { $0 + detail.fileCount($1) } }
    private var totalBytes: Double { detail.orderedEditions.reduce(0) { $0 + bytes($1) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heading
                VStack(spacing: 0) {
                    ForEach(Array(detail.orderedEditions.enumerated()), id: \.element.id) { index, edition in
                        folderRow(edition)
                        if index < detail.orderedEditions.count - 1 { Divider().padding(.leading, 54) }
                    }
                    Divider()
                    Toggle(isOn: $deleteFiles) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Also delete the files").font(.system(size: 15.5, weight: .semibold))
                            Text(filesLine).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                        }
                    }
                    .tint(Theme.danger)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(Theme.txt.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                buttons
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDragIndicator(.visible)
        .retainsDraft("delete.deleteFiles", $deleteFiles)
    }

    private var heading: some View {
        VStack(spacing: 6) {
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.danger)
                .frame(width: 52, height: 52)
                .background(Theme.danger.opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            Text("Delete \(detail.title)?")
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            Text(detail.orderedEditions.count > 1
                 ? "It leaves your library and stops being searched. Every version goes."
                 : "It leaves your library and stops being searched.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.txt)
        .frame(maxWidth: .infinity)
    }

    private func folderRow(_ edition: DetailEdition) -> some View {
        let files = detail.fileCount(edition)
        let size = bytes(edition)
        let parts: [String?] = [edition.label, "\(files) file\(files == 1 ? "" : "s")", size > 0 ? DetailText.bytes(size) : nil]
        return HStack(spacing: 12) {
            EditionBadge(tier: edition.tier, state: files > 0 ? .onDisk : .missing, showsCount: false)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder(edition))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(parts.compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button(role: .destructive) {
                Task {
                    busy = true
                    let ok = await store.deleteItem(deleteFiles: deleteFiles)
                    busy = false
                    if ok { dismiss() }
                }
            } label: {
                Label(busy ? "Deleting…" : "Delete \(noun)", systemImage: "trash")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.danger)
            .controlSize(.large)
            .disabled(busy)
            Button { dismiss() } label: {
                Text("Cancel").font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
    }

    private var filesLine: String {
        guard fileCount > 0 else { return "There are no files on disk." }
        let size = totalBytes > 0 ? " · \(DetailText.bytes(totalBytes))" : ""
        return "\(fileCount) file\(fileCount == 1 ? "" : "s")\(size). This cannot be undone."
    }

    private func folder(_ edition: DetailEdition) -> String {
        if let path = edition.fullPath, !path.isEmpty { return path }
        let root = store.rootPath(edition)
        guard let name = edition.folderName, !name.isEmpty else { return root }
        return root == "—" ? name : (root as NSString).appendingPathComponent(name)
    }

    private func bytes(_ edition: DetailEdition) -> Double {
        detail.isSeries ? (store.summary(edition)?.bytes ?? 0) : (edition.movieFile?.size ?? 0)
    }
}
