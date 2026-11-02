import SwiftUI
import FusionhaKit

/// Tab 2 (web `ExclusionsTab`): titles import lists never add, every list or
/// one, with Exclude a title, a filter, and the pointer to Discover's ignores.
struct ImportListExclusionsTab: View {
    enum Filter: String, CaseIterable { case all, every, one }

    @Environment(AppModel.self) private var model
    let store: ImportListsStore
    @State private var filter: Filter = .all
    @State private var adding = false

    var body: some View {
        Section {
            Button("Exclude a title", systemImage: "plus") { adding = true }
            Picker("Filter exclusions", selection: $filter) {
                Text("All \(store.exclusions?.count ?? 0)").tag(Filter.all)
                Text("Every list").tag(Filter.every)
                Text("One list").tag(Filter.one)
            }
            .pickerStyle(.segmented)
            rows
        } header: {
            Text("Exclusions")
        } footer: {
            Text(ImportListCopy.exclusionsDesc)
        }
        .task { await store.loadExclusions(model.client) }
        .sheet(isPresented: $adding) { ImportListExclusionAddSheet(store: store) }
        Section {
            Button("Open Discover", systemImage: "safari") { model.openSettings(panel: "discover") }
        } header: {
            Text("Discover ignores")
        } footer: {
            Text(ImportListCopy.ignoresDesc)
        }
    }

    @ViewBuilder private var rows: some View {
        if let all = store.exclusions {
            let shown = all.filter { filter == .all || (filter == .every) == $0.everyList }
            if shown.isEmpty {
                Text(ImportListCopy.noExclusions).font(.subheadline).foregroundStyle(Theme.mut)
            }
            ForEach(shown) { row($0) }
        } else {
            SettingsLoadingRow(error: store.exclusionsFailed ? "Couldn’t load exclusions." : nil)
        }
    }

    private func row(_ e: ImportListExclusion) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(e.title.map { ImportListCopy.titleWithYear($0, e.year) } ?? "TMDB \(e.tmdbId ?? 0)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                HStack(spacing: 6) {
                    Text(e.kind == "movie" ? "Movie" : "Series")
                        .foregroundStyle(e.kind == "movie" ? Theme.kindMovie : Theme.kindSeries)
                    Text("·")
                    Text(e.everyList ? "Every list" : (store.list(e.listId)?.name ?? "One list"))
                    if let at = e.createdAt { Text("· \(WatchlistTime.lastRun(at))") }
                }
                .font(.caption).foregroundStyle(Theme.mut).lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .swipeActions {
            Button("Remove", systemImage: "trash", role: .destructive) { Task { await store.removeExclusion(e, model) } }
        }
        .contextMenu {
            Button("Remove exclusion", systemImage: "trash", role: .destructive) { Task { await store.removeExclusion(e, model) } }
        }
    }
}

/// "Exclude a title": search TMDB, pick a title, then every list or one list.
struct ImportListExclusionAddSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: ImportListsStore
    @State private var term = ""
    @State private var picked: MediaSearchResult?
    @State private var everyList = true
    @State private var listId: Int?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                ImportListTitlePicker(label: "Exclude a title", placeholder: "Search a title to exclude", term: $term, picked: $picked)
                if let picked {
                    Section("Exclude \(ImportListCopy.titleWithYear(picked.title, picked.year)) on") {
                        Picker("Exclude on", selection: $everyList) {
                            Text("Every list").tag(true)
                            Text("One list").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .disabled(store.lists.isEmpty)
                        if !everyList {
                            Picker("Which list", selection: $listId) {
                                Text("Choose a list").tag(Int?.none)
                                ForEach(store.lists) { Text($0.name).tag(Int?.some($0.id)) }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Exclude a title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Exclude") { submit() }
                        .disabled(picked == nil || saving || (!everyList && listId == nil))
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func submit() {
        guard let picked else { return }
        saving = true
        Task {
            defer { saving = false }
            if await store.exclude(picked, listId: everyList ? nil : listId, model) { dismiss() }
        }
    }
}
