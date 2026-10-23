import SwiftUI
import UIKit
import FusionhaKit

// The movie Versions tab's cards (MovieVersionsTable, mobile): an owned
// version (file, facts, search / edit / import / replace / delete) and a
// wanted one (target profile, the download pill while grabbing, search).

struct DetailOwnedEditionCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let edition: DetailEdition
    @State private var confirmDelete = false
    @State private var confirmDead: DeadAction?
    @State private var editing: MovieFileEditTarget?

    private enum DeadAction { case replace, cleanup }

    var body: some View {
        let file = edition.movieFile
        let probe = file?.mediaInfo?.probe
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                DetailStatusIconBox(dot: store.dot(edition))
                TierPill(tier: edition.tier, large: true).fixedSize()
                if !edition.versionKey.isEmpty { DetailVersionTag(text: edition.versionKey) }
                if let file { DetailAnalysisBadge(file: file) }
                Spacer(minLength: 0)
                DetailMonitorBookmark(edition: edition)
            }
            Text(file?.relativePath ?? "")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            FlowRow(spacing: 10, lineSpacing: 6) {
                DetailQualityChip(quality: file?.quality, tier: edition.tier)
                if let v = DetailMediaFacts.codec(probe) { Text(v) }
                Text(DetailMediaFacts.audio(probe) ?? "—")
                if let v = DetailMediaFacts.range(probe) { Text(v) }
                Text(DetailText.bytes(file?.size))
                if let g = file?.releaseGroup, !g.isEmpty { Text(g) }
                Button {
                    UIPasteboard.general.string = file?.relativePath
                    store.show("Path copied", variant: .success)
                } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy path")
            }
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(Theme.mut)
            HStack(spacing: 8) {
                if model.me?.can("search") ?? true {
                    SearchActionButton(label: edition.label, editionId: edition.id, size: 40, glyph: 15, bordered: true)
                    DetailSquareAction(systemImage: "person", label: "Interactive search", size: 40) {
                        store.interactive = InteractiveTarget(editionIds: [edition.id], subtitle: edition.label)
                    }
                }
                if model.me?.can("edit") ?? true, let file {
                    DetailSquareAction(systemImage: "pencil", label: "Edit movie file", size: 40) {
                        editing = MovieFileEditTarget(versionId: edition.id, fileId: file.id)
                    }
                    DetailSquareAction(systemImage: "square.and.arrow.down", label: "Manual import", size: 40) {
                        store.manageFiles = ManageFilesTarget(versionIds: [edition.id], season: nil)
                    }
                }
                if let file, file.linkUnresolved == true, model.me?.can("manage_files") ?? true {
                    let monitored = store.editionMonitored(edition)
                    DetailSquareAction(systemImage: monitored ? "arrow.triangle.2.circlepath" : "link.badge.plus",
                                       label: monitored ? "Replace file" : "Clean up dead link", size: 40) {
                        confirmDead = monitored ? .replace : .cleanup
                    }
                }
                if model.me?.can("delete_files") ?? true {
                    DetailSquareAction(systemImage: "trash", label: "Delete file", size: 40) { confirmDelete = true }
                }
            }
        }
        .padding(16)
        .detailCard()
        .confirmationDialog("Delete this file?", isPresented: $confirmDelete, titleVisibility: .visible) {
            if let id = file?.id {
                Button("Delete", role: .destructive) { Task { await store.deleteFile(id, blocklist: false) } }
                Button("Delete & blocklist", role: .destructive) { Task { await store.deleteFile(id, blocklist: true) } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(confirmDead == .replace ? "Replace this file? (delete + re-grab)" : "Clean up this file? (delete)",
                            isPresented: Binding(get: { confirmDead != nil }, set: { if !$0 { confirmDead = nil } }),
                            titleVisibility: .visible) {
            if let id = file?.id {
                if confirmDead == .replace {
                    Button("Replace", role: .destructive) { Task { await store.replaceFile(id) } }
                } else {
                    Button("Clean up", role: .destructive) { Task { await store.cleanupLink(id) } }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .duoPageSheet(item: $editing) { target in
            MovieFileEditSheet(detail: detail, target: target)
        }
    }
}

struct DetailWantedEditionCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let edition: DetailEdition
    @State private var searching = false

    var body: some View {
        let cutoff = store.cutoff(edition.qualityProfileId).map { DetailText.quality($0) } ?? "—"
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                DetailStatusIconBox(dot: store.dot(edition))
                TierPill(tier: edition.tier, large: true).fixedSize()
                if !edition.versionKey.isEmpty { DetailVersionTag(text: edition.versionKey) }
                Spacer(minLength: 0)
                DetailMonitorBookmark(edition: edition)
            }
            if edition.downloadState == "downloading" || edition.downloadState == "upgrading" {
                DetailDownloadPill(edition: edition)
            }
            (Text("Target profile ") + Text(store.profileName(edition.qualityProfileId)).fontWeight(.bold).foregroundColor(Theme.txt)
                + Text(" · cutoff \(cutoff)"))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
            HStack(spacing: 8) {
                if model.me?.can("search") ?? true {
                    Button {
                        searching = true
                        Task {
                            await store.search(label: edition.label, editionId: edition.id)
                            searching = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if searching { DetailSpinner(size: 12, color: Theme.done) } else { Image(systemName: "magnifyingglass") }
                            Text("Search")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(DetailPressStyle())
                    .glassControl()
                    .disabled(searching)
                    DetailSquareAction(systemImage: "person", label: "Interactive search", size: 40) {
                        store.interactive = InteractiveTarget(editionIds: [edition.id], subtitle: edition.label)
                    }
                }
                if model.me?.can("edit") ?? true {
                    DetailSquareAction(systemImage: "pencil", label: "Edit version", size: 40) { store.showingEdit = true }
                }
            }
        }
        .padding(16)
        .detailCard()
    }
}
