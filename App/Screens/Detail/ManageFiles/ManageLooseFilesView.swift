import SwiftUI
import FusionhaKit

/// Import loose files (web `LooseImportPanel`): unregistered videos under the
/// title's root folders, each attached in place to a version (a series also to
/// its episode, parsed from the name or picked) or deleted from disk.
struct ManageLooseFilesView: View {
    let detail: ItemDetail
    @Environment(AppModel.self) private var app
    @Environment(DetailStore.self) private var store
    @State private var files: [LooseFile] = []
    @State private var loaded = false
    @State private var working: String?
    @State private var target: Int?
    @State private var error: String?
    @State private var deleting: LooseFile?

    private var versionId: Int? { target ?? detail.editions.first?.id }

    var body: some View {
        List {
            if detail.editions.count > 1 {
                Picker("Attach to version", selection: Binding(get: { versionId ?? 0 }, set: { target = $0 })) {
                    ForEach(detail.orderedEditions) { e in
                        Text(VersionLabel.text(tier: e.tier, edition: e.movieEdition) ?? e.tier.chipLabel).tag(e.id)
                    }
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
            if !loaded {
                HStack(spacing: 10) { ProgressView(); Text("Scanning for loose files…").foregroundStyle(Theme.mut) }
            } else if files.isEmpty {
                Text("No loose files under this title’s root folders.").foregroundStyle(Theme.mut)
            } else {
                Section {
                    ForEach(files) { f in row(f) }
                } footer: {
                    Text("Import attaches the file where it is. Nothing is moved or downloaded.")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog("Delete \(deleting?.name ?? "this file")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { f in
            Button("Delete from disk", role: .destructive) { Task { await delete(f) } }
        } message: { _ in
            Text("The file isn’t part of the library, so this only removes it from disk.")
        }
    }

    private func row(_ f: LooseFile) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(f.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.txt).lineLimit(2).truncationMode(.middle)
                Text([parsedCode(f), f.quality.map { DetailText.quality($0) }].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            if working == f.path {
                ProgressView()
            } else {
                importControl(f)
                Button("Delete", systemImage: "trash", role: .destructive) { deleting = f }
                    .labelStyle(.iconOnly).buttonStyle(.borderless).tint(Theme.danger)
            }
        }
        .disabled(working != nil)
    }

    @ViewBuilder private func importControl(_ f: LooseFile) -> some View {
        if detail.kind != .series {
            Button("Import") { Task { await attach(f, episodeId: nil) } }.buttonStyle(.bordered)
        } else if let ep = parsedEpisode(f) {
            Button("Import") { Task { await attach(f, episodeId: ep.id) } }.buttonStyle(.bordered)
        } else {
            Menu("Import as…") {
                ForEach(detail.seasons ?? []) { s in
                    Menu(s.seasonNumber == 0 ? "Specials" : "Season \(s.seasonNumber)") {
                        ForEach(s.episodes) { e in
                            Button(EpisodeCode.episode(season: s.seasonNumber, episode: e.episodeNumber) + (e.title.map { " · \($0)" } ?? "")) {
                                Task { await attach(f, episodeId: e.id) }
                            }
                        }
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func parsedCode(_ f: LooseFile) -> String? {
        guard let s = f.season, let e = f.episodes?.first else { return nil }
        return EpisodeCode.episode(season: s, episode: e)
    }

    private func parsedEpisode(_ f: LooseFile) -> Episode? {
        guard let s = f.season, let n = f.episodes?.first else { return nil }
        return detail.seasons?.first { $0.seasonNumber == s }?.episodes.first { $0.episodeNumber == n }
    }

    private func load() async {
        guard let client = app.client else { return }
        do {
            files = try await client.looseFiles(itemId: detail.id)
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t scan for loose files.")
        }
        loaded = true
    }

    private func attach(_ f: LooseFile, episodeId: Int?) async {
        guard let client = app.client, let versionId else { return }
        working = f.path
        defer { working = nil }
        do {
            files = try await client.importLooseFile(itemId: detail.id, path: f.path, versionId: versionId, episodeId: episodeId)
            error = nil
            await store.reload()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t import that file.")
        }
    }

    private func delete(_ f: LooseFile) async {
        guard let client = app.client else { return }
        working = f.path
        defer { working = nil }
        do {
            files = try await client.deleteLooseFile(itemId: detail.id, path: f.path)
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t delete that file.")
        }
    }
}
