import SwiftUI
import UIKit
import FusionhaKit

/// v2's Files tab for a movie (mock browse-title.js `movieFiles`): "2 files
/// · 39.3 GB" and Rename files, then one file card per version in scope
/// (`V2EpisodeFileCard`: quality, release, score, facts grid, custom
/// formats, path) with its actions inside it, under the path. A version
/// with no file gets a short card with its searches.
struct V2MovieFilesTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail

    var body: some View {
        let editions = store.scopedEditions
        let owned = editions.filter { $0.movieFile != nil }
        let bytes = owned.compactMap { $0.movieFile?.size }.reduce(0, +)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\(owned.count) file\(owned.count == 1 ? "" : "s")\(owned.isEmpty ? "" : " · \(DetailText.bytes(bytes))")")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                Spacer(minLength: 8)
                if (model.me?.can("edit") ?? true) && !owned.isEmpty { V2RenameFilesButton() }
            }
            .v2FadesUnderTitleBar()
            ForEach(editions) { edition in
                if let file = edition.movieFile {
                    V2EpisodeFileCard(version: edition, file: file, monitored: store.editionMonitored(edition),
                                      footer: AnyView(V2MovieFileActions(detail: detail, edition: edition, file: file)))
                } else {
                    V2MovieWantedCard(edition: edition)
                }
            }
        }
    }
}

/// Edit quality, Replace (a dead link), More (Manual import, Clean up,
/// Copy path) and Delete, as v1's owned-version card does them.
struct V2MovieFileActions: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let edition: DetailEdition
    let file: MovieFile
    @State private var editing: MovieFileEditTarget?
    @State private var confirmDelete = false
    @State private var confirmReplace = false

    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var canManage: Bool { model.me?.can("manage_files") ?? true }
    private var dead: Bool { file.linkUnresolved == true }

    var body: some View {
        HStack(spacing: 8) {
            if canEdit {
                Button("Edit quality", systemImage: "pencil") {
                    editing = MovieFileEditTarget(versionId: edition.id, fileId: file.id)
                }
            }
            if dead, canManage, store.editionMonitored(edition) {
                Button("Replace", systemImage: "arrow.triangle.2.circlepath") { confirmReplace = true }
            }
            more
            Spacer(minLength: 0)
            if model.me?.can("delete_files") ?? true {
                Button("Delete file", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Theme.danger)
            }
        }
        .font(.system(size: 13.5, weight: .semibold))
        .foregroundStyle(page?.ink ?? Theme.txt)
        .buttonStyle(.glass)
        .v2FadesUnderTitleBar()
        .confirmationDialog("Delete this file?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await store.deleteFile(file.id, blocklist: false) } }
            Button("Delete and blocklist", role: .destructive) { Task { await store.deleteFile(file.id, blocklist: true) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(((file.relativePath ?? "") as NSString).lastPathComponent)
        }
        .confirmationDialog("Replace this file? (delete + re-grab)", isPresented: $confirmReplace, titleVisibility: .visible) {
            Button("Replace", role: .destructive) { Task { await store.replaceFile(file.id) } }
            Button("Cancel", role: .cancel) {}
        }
        .duoPageSheet(item: $editing) { target in
            MovieFileEditSheet(detail: detail, target: target)
        }
    }

    private var more: some View {
        Menu {
            if canEdit {
                Button("Manual import", systemImage: "square.and.arrow.down") {
                    store.manageFiles = ManageFilesTarget(versionIds: [edition.id], season: nil)
                }
            }
            if dead, canManage {
                Button("Clean up dead link", systemImage: "link.badge.plus") { Task { await store.cleanupLink(file.id) } }
            }
            Button("Copy path", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = V2EpisodeFilePath.full(file, version: edition, store: store)
                store.show("Path copied", variant: .success)
            }
            V2BlockGroupButton(group: file.releaseGroup)
        } label: {
            Label("More", systemImage: "ellipsis").labelStyle(.iconOnly)
        }
        .accessibilityLabel("More for the \(edition.tier.badgeLetters) file")
    }
}

/// A version with no file: its outline badge, what it aims for, and its
/// searches (mock `vrow` without a file).
struct V2MovieWantedCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let edition: DetailEdition
    @State private var searching = false

    private var downloading: Bool { edition.downloadState == "downloading" || edition.downloadState == "upgrading" }

    var body: some View {
        let cutoff = store.cutoff(edition.qualityProfileId).map { DetailText.quality($0) } ?? "—"
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                EditionBadge(tier: edition.tier, state: downloading ? .downloading(progress: nil) : .missing,
                             showsCount: false)
                Text(downloading ? "Downloading" : "No file yet")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
            }
            Text("\(store.profileName(edition.qualityProfileId)) · cutoff \(cutoff)")
                .font(.system(size: 12.5))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .lineLimit(1)
            if model.me?.can("search") ?? true {
                HStack(spacing: 8) {
                    Button {
                        searching = true
                        Task {
                            await store.search(label: edition.label, editionId: edition.id)
                            searching = false
                        }
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .disabled(searching)
                    Button("Interactive search", systemImage: "person") {
                        store.interactive = InteractiveTarget(editionIds: [edition.id], subtitle: edition.label)
                    }
                    .labelStyle(.iconOnly)
                }
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .buttonStyle(.glass)
                .v2FadesUnderTitleBar()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 22) }
    }
}
