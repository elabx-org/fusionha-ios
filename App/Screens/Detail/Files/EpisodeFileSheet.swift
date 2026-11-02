import SwiftUI
import UIKit
import FusionhaKit

/// Which episode file the file sheet shows. The sheet looks the file up in
/// the live detail, so a reload (or a fold / unfold re-host) shows it fresh.
struct EpisodeFileTarget: Identifiable, Hashable {
    let fileId: Int
    let editionId: Int
    let seasonNumber: Int
    var id: Int { fileId }
}

/// The Files tab's row sheet: `S01E01` with the version chip and the episode
/// title, a lifted card of facts, the full path with Copy, the dead-link
/// clean-up, and Delete file (with "Delete" / "Delete and blocklist").
struct EpisodeFileSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let target: EpisodeFileTarget
    @State private var confirmDelete = false

    private var edition: DetailEdition? { store.detail?.editions.first { $0.id == target.editionId } }
    private var row: SeasonFileRow? {
        let season = store.detail?.seasons?.first { $0.seasonNumber == target.seasonNumber }
        return season?.fileRows(editionId: target.editionId).first { $0.file?.id == target.fileId }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let row, let file = row.file, let edition {
                    ScrollView { content(row: row, file: file, edition: edition).padding(20) }
                } else {
                    EmptyBox(message: "This file is no longer in the library.")
                        .padding(20)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton(title: "Close") { dismiss() } }
            }
            .closeOnlyBars()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func content(row: SeasonFileRow, file: MovieFile, edition: DetailEdition) -> some View {
        let facts = EpisodeFileFacts(file: file, tier: edition.tier)
        return VStack(alignment: .leading, spacing: 16) {
            heading(row: row, edition: edition)
            EpisodeFileFactsCard(facts: facts, onDisk: onDisk(file, facts: facts))
            EpisodeFilePathBox(path: file.relativePath ?? "") {
                UIPasteboard.general.string = file.relativePath
                store.show("Path copied", variant: .success)
            }
            actions(file: file, facts: facts)
        }
        .confirmationDialog("Delete this file?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete(file.id, blocklist: false) }
            Button("Delete and blocklist", role: .destructive) { delete(file.id, blocklist: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(((file.relativePath ?? "") as NSString).lastPathComponent)
        }
    }

    private func heading(row: SeasonFileRow, edition: DetailEdition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(EpisodeCode.fileCode(season: target.seasonNumber, episodes: row.episodes.map(\.episodeNumber)))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                DetailTierChip(tier: edition.tier, label: edition.label)
            }
            Text(row.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// `Imported · symlink`, or the dead link in the stuck colour.
    private func onDisk(_ file: MovieFile, facts: EpisodeFileFacts) -> String {
        if facts.deadLink { return "Dead link · target gone from disk" }
        guard let mode = file.mediaInfo?.finalMode, !mode.isEmpty else { return "Imported" }
        return "Imported · \(mode.lowercased())"
    }

    @ViewBuilder
    private func actions(file: MovieFile, facts: EpisodeFileFacts) -> some View {
        if facts.deadLink, model.me?.can("manage_files") ?? true {
            Button {
                Task { await store.cleanupLink(file.id) }
            } label: {
                Label("Clean up dead link", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Theme.i2)
        }
        if model.me?.can("delete_files") ?? true {
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete file", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Theme.danger)
        }
    }

    private func delete(_ fileId: Int, blocklist: Bool) {
        dismiss()
        Task { await store.deleteFile(fileId, blocklist: blocklist) }
    }
}
