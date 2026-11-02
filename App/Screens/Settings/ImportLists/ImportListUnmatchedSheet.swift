import SwiftUI
import FusionhaKit

/// Titles a list couldn't match (web `UnmatchedSheet`): add the right one
/// from TMDB, or ignore it here or on every list.
struct ImportListUnmatchedSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: ImportListsStore
    let list: ImportList
    @State private var items: [ImportListItem]?
    @State private var adding: Int?
    @State private var term = ""
    @State private var picked: MediaSearchResult?
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {} footer: {
                    Text(ImportListCopy.reviewDesc(items?.count ?? list.unmatchedCount, list: list.name))
                }
                if let items {
                    if items.isEmpty { Section { Text(ImportListCopy.nothingLeft).foregroundStyle(Theme.mut) } }
                    ForEach(items) { item in
                        row(item)
                        if adding == item.id { picker(item) }
                    }
                } else {
                    Section { SettingsLoadingRow(error: failed ? ImportListCopy.unmatchedFailed : nil) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle(ImportListCopy.reviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await load() }
        }
        .presentationDragIndicator(.visible)
    }

    private func row(_ item: ImportListItem) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                Text(ImportListCopy.reason(item.unmatchedReason)).font(.caption).foregroundStyle(Theme.mut)
            }
            HStack(spacing: 14) {
                Button("Add it", systemImage: "plus") {
                    adding = adding == item.id ? nil : item.id
                    term = item.title ?? ""
                    picked = nil
                }
                Button("Ignore") { Task { await ignore(item, everywhere: false) } }
                Button("Ignore on every list") { Task { await ignore(item, everywhere: true) } }
            }
            .buttonStyle(.borderless)
            .font(.footnote)
            .disabled(busy)
        }
    }

    @ViewBuilder private func picker(_ item: ImportListItem) -> some View {
        ImportListTitlePicker(label: "Search TMDB", term: $term, picked: $picked)
        Section {
            Button("Add this title") { Task { await resolve(item) } }
                .disabled(picked == nil || busy)
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            items = try await client.importListUnmatched(list.id)
            failed = false
        } catch {
            if items == nil { failed = true }
        }
    }

    private func resolve(_ item: ImportListItem) async {
        guard let client = model.client, let picked else { return }
        await act {
            _ = try await client.resolveImportListItem(list.id, itemId: item.id, tmdbId: picked.tmdbId, kind: picked.kind)
            model.toast("\(ImportListCopy.titleWithYear(picked.title, picked.year)) is added")
        }
    }

    private func ignore(_ item: ImportListItem, everywhere: Bool) async {
        guard let client = model.client else { return }
        await act {
            _ = try await client.ignoreImportListItem(list.id, itemId: item.id, everywhere: everywhere)
            model.toast(everywhere ? "Ignored on every list" : "Ignored on this list")
        }
    }

    /// One review write, then the list and the panel are read again.
    private func act(_ call: () async throws -> Void) async {
        busy = true
        defer { busy = false }
        do {
            try await call()
            adding = nil
            await load()
            await store.load(model.client)
            await store.loadExclusions(model.client)
        } catch {
            model.toast(ImportListCopy.serverMessage(error, fallback: SourceDetailCopy.failed), variant: .error)
        }
    }
}
