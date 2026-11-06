import SwiftUI
import UIKit
import FusionhaKit

/// The episode page's bar (mock `gcap`): Automatic search, Interactive
/// search (person) and the file's ⋯, all for this episode.
struct V2EpisodeToolbar: ToolbarContent {
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int
    /// The version the page shows: the ⋯ acts on its file.
    let version: DetailEdition?

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            V2EpisodeSearchButtons(detail: detail, episode: episode, seasonNumber: seasonNumber)
            V2EpisodeFileMenu(detail: detail, episode: episode, seasonNumber: seasonNumber, version: version)
        }
    }
}

/// Automatic search (every monitored version of this episode) and Interactive search.
private struct V2EpisodeSearchButtons: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int

    private var activity: SearchActivity? { store.activity(.episode(episode.id)) }
    private var code: String { EpisodeCode.episode(season: seasonNumber, episode: episode.episodeNumber) }
    private var canSearch: Bool { (model.me?.can("edit") ?? true) && (model.me?.can("search") ?? true) }

    var body: some View {
        if canSearch {
            Button {
                store.v2Search(.episode(episode.id), label: "\(detail.title) \(code)", episodeId: episode.id)
            } label: {
                V2SearchLabel(title: "Automatic search", activity: activity)
            }
            .disabled(activity?.isSearching == true)
            Button {
                store.interactive = InteractiveTarget(editionIds: detail.orderedEditions.map(\.id), episodeId: episode.id,
                                                      subtitle: "S\(seasonNumber)·E\(episode.episodeNumber)")
            } label: {
                Label("Interactive search", systemImage: "person")
            }
        }
    }
}

/// The file's actions (mock browse-sheets.js `fileMenu`): Copy path,
/// Replace (search again), Clean up a dead link, Delete file and Delete
/// and blocklist, each v1's file call. Deleting asks first.
struct V2EpisodeFileMenu: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int
    let version: DetailEdition?
    @State private var confirm: Confirm?

    enum Confirm: Identifiable {
        case delete(blocklist: Bool), replace
        var id: String {
            switch self {
            case .delete(let blocklist): return blocklist ? "blocklist" : "delete"
            case .replace: return "replace"
            }
        }
    }

    private var file: MovieFile? { version.flatMap { episode.file(for: $0.id) } }
    private var canManage: Bool { model.me?.can("manage_files") ?? true }
    private var canDelete: Bool { model.me?.can("delete_files") ?? true }

    var body: some View {
        Menu {
            if let file, let version {
                Section(version.label) {
                    Button("Copy path", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = V2EpisodeFilePath.full(file, version: version, store: store)
                        store.show("Path copied", variant: .success)
                    }
                    if canManage {
                        Button("Replace (search again)", systemImage: "arrow.triangle.2.circlepath") { confirm = .replace }
                        if file.linkUnresolved == true, !store.editionMonitored(version) {
                            Button("Clean up dead link", systemImage: "link") {
                                Task { await store.cleanupLink(file.id) }
                            }
                        }
                    }
                }
                if canDelete {
                    Section {
                        Button("Delete file…", systemImage: "trash", role: .destructive) { confirm = .delete(blocklist: false) }
                        Button("Delete and blocklist…", systemImage: "nosign", role: .destructive) { confirm = .delete(blocklist: true) }
                    }
                }
            } else {
                Text(version.map { "No \($0.label) file for this episode" } ?? "No file for this episode")
            }
        } label: {
            Label("File actions", systemImage: "ellipsis")
        }
        .confirmationDialog(title, isPresented: presented, titleVisibility: .visible, presenting: confirm) { choice in
            switch choice {
            case .delete(let blocklist):
                Button(blocklist ? "Delete and blocklist" : "Delete", role: .destructive) { run(choice) }
            case .replace:
                Button("Replace", role: .destructive) { run(choice) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { choice in
            switch choice {
            case .delete(let blocklist):
                Text(blocklist ? "The file goes, and this release is never grabbed again." : "The file goes from disk.")
            case .replace:
                Text("Deletes it and grabs it again.")
            }
        }
    }

    private var title: String {
        guard let file else { return "" }
        let name = ((file.relativePath ?? "") as NSString).lastPathComponent
        if case .replace? = confirm { return "Replace \(name)?" }
        return "Delete \(name)?"
    }

    private var presented: Binding<Bool> {
        Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })
    }

    private func run(_ choice: Confirm) {
        guard let file else { return }
        Task {
            switch choice {
            case .delete(let blocklist): await store.deleteFile(file.id, blocklist: blocklist)
            case .replace: await store.replaceFile(file.id)
            }
        }
    }
}

/// A file's full path: its version's root joined with the relative path (v1's rule).
enum V2EpisodeFilePath {
    @MainActor
    static func full(_ file: MovieFile, version: DetailEdition, store: DetailStore) -> String {
        let root = store.rootPath(version)
        guard let rel = file.relativePath else { return root }
        return root == "—" ? rel : (root as NSString).appendingPathComponent(rel)
    }
}
