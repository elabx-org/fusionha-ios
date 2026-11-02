import SwiftUI
import UIKit
import FusionhaKit

/// One owned file of the episode, in the Files tab's style: the version chip
/// with its labelled score, the "below this version" note, the facts, the
/// path, then Copy path and Delete file (Delete or Delete and blocklist, as
/// the file sheet asks). A dead link offers Replace or Clean up.
struct EpisodeFileCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let version: DetailEdition
    let file: MovieFile
    let monitored: Bool
    @State private var confirmDelete = false
    @State private var confirmLink = false

    private var fileFacts: EpisodeFileFacts { EpisodeFileFacts(file: file, tier: version.tier) }

    private var fullPath: String {
        let root = store.rootPath(version)
        guard let rel = file.relativePath else { return root }
        return root == "—" ? rel : (root as NSString).appendingPathComponent(rel)
    }

    var body: some View {
        let facts = fileFacts
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                header
                if let note = facts.belowTierNote(version.tier) {
                    Label(note, systemImage: "arrow.up.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(EditionStatus.upgrading.color)
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            EpisodeFileFactsCard(facts: facts, onDisk: facts.onDisk(file), framed: false)
            Text(file.relativePath ?? fullPath)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.mut)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            actions
        }
        .padding(16)
        .detailCard(radius: 16, shadow: false)
        .confirmationDialog("Delete this file?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { run { await store.deleteFile(file.id, blocklist: false) } }
            Button("Delete and blocklist", role: .destructive) { run { await store.deleteFile(file.id, blocklist: true) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(((file.relativePath ?? "") as NSString).lastPathComponent)
        }
        .confirmationDialog(monitored ? "Replace this file?" : "Clean up this file?",
                            isPresented: $confirmLink, titleVisibility: .visible) {
            Button(monitored ? "Replace" : "Clean up", role: .destructive) {
                run {
                    if monitored { await store.replaceFile(file.id) } else { await store.cleanupLink(file.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(monitored ? "Deletes it and grabs it again." : "Deletes it.")
        }
    }

    /// `HD·1080p  version` … `Score +1,000`.
    private var header: some View {
        HStack(spacing: 8) {
            DetailTierChip(tier: version.tier, label: version.label)
            Text("version").font(.system(size: 14)).foregroundStyle(Theme.mut)
            if file.unresolved == true {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(Theme.stuck)
                    .accessibilityLabel("File needs attention")
            }
            DetailAnalysisBadge(file: file)
            Spacer(minLength: 8)
            if let score = file.cfScore {
                (Text("Score ").foregroundColor(Theme.mut)
                    + Text(DetailText.score(score))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(score < 0 ? Theme.danger : Theme.txt))
                    .font(.system(size: 13))
                    .accessibilityLabel("Custom format score \(DetailText.score(score))")
            }
        }
    }

    /// Copy path on the leading side, Delete file on the trailing side.
    private var actions: some View {
        HStack(spacing: 16) {
            Button {
                UIPasteboard.general.string = fullPath
                store.show("Path copied", variant: .success)
            } label: {
                Label("Copy path", systemImage: "doc.on.doc")
            }
            .foregroundStyle(Theme.i2)
            Spacer(minLength: 8)
            if file.linkUnresolved == true, model.me?.can("manage_files") ?? true {
                Button(monitored ? "Replace" : "Clean up",
                       systemImage: monitored ? "arrow.triangle.2.circlepath" : "link") { confirmLink = true }
                    .foregroundStyle(Theme.i2)
            }
            if model.me?.can("delete_files") ?? true {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete file", systemImage: "trash")
                }
                .foregroundStyle(Theme.danger)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private func run(_ action: @escaping () async -> Void) {
        Task { await action() }
    }
}
