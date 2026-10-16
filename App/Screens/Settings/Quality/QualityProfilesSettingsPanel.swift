import SwiftUI
import FusionhaKit

/// Settings › Quality › Quality Profiles (web `QualityProfilesPanel`): every
/// profile with its resolution ladder, custom-format count and badges, filtered
/// by kind and name. Tap a profile to edit it; swipe or long-press to duplicate
/// or delete it; "New profile" opens the same editor empty.
struct QualityProfilesSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var profiles: [QualityProfileRecord]?
    @State private var error: String?
    @State private var tab = "all"
    @State private var query = ""
    @State private var editing: QualityProfileEditTarget?
    @State private var deleting: QualityProfileRecord?
    @State private var actionError: String?

    private static let tabs = [("all", "All"), ("movie", "Movies"), ("series", "Series"), ("anime", "Anime")]

    var body: some View {
        SettingsForm(slug: "profiles") {
            controls
            if let error {
                SettingsLoadingRow(error: error)
            } else if let profiles {
                list(profiles)
            } else {
                SettingsLoadingRow()
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { target in
            QualityProfileEditorSheet(profile: target.profile) { await load() }
        }
        .confirmationDialog("Delete \(deleting?.name ?? "this profile")?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { p in
            Button("Delete", role: .destructive) { Task { await delete(p) } }
        }
    }

    private var controls: some View {
        Section {
            Picker("Filter by kind", selection: $tab) {
                ForEach(Self.tabs, id: \.0) { t in
                    Text("\(t.1) \(count(t.0))").tag(t.0)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.dim)
                TextField("Search profiles…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .settingsField("Search profiles")
            Button("New profile", systemImage: "plus") { editing = .new }
                .settingsField("New profile")
            if let actionError {
                Text(actionError).font(.footnote).foregroundStyle(Theme.danger).listRowBackground(Theme.card)
            }
        }
    }

    @ViewBuilder
    private func list(_ all: [QualityProfileRecord]) -> some View {
        let shown = filtered(all)
        if shown.isEmpty {
            Section {
                Text(all.isEmpty ? "No quality profiles yet — create one to start tracking versions."
                                 : "No profiles match this filter.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
            .listRowBackground(Theme.card)
        } else {
            Section {
                ForEach(shown) { p in
                    Button { editing = .edit(p) } label: { QualityProfileRow(profile: p) }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) { deleting = p }
                            Button("Duplicate", systemImage: "plus.square.on.square") { Task { await duplicate(p) } }
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { editing = .edit(p) }
                            Button("Duplicate", systemImage: "plus.square.on.square") { Task { await duplicate(p) } }
                            Button("Delete", systemImage: "trash", role: .destructive) { deleting = p }
                        }
                }
            }
            .listRowBackground(Theme.card)
            .listRowSeparatorTint(Theme.line)
        }
    }

    private func count(_ tab: String) -> Int {
        guard let profiles else { return 0 }
        return tab == "all" ? profiles.count : profiles.filter { $0.mediaKind == tab }.count
    }

    private func filtered(_ all: [QualityProfileRecord]) -> [QualityProfileRecord] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return all.filter { p in
            (tab == "all" || p.mediaKind == tab) && (needle.isEmpty || p.name.lowercased().contains(needle))
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            profiles = try await client.qualityProfileRecords()
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the quality profiles.")
        }
    }

    private func duplicate(_ p: QualityProfileRecord) async {
        guard let client = model.client else { return }
        do {
            try await client.createQualityProfile(QualityProfileBody.duplicate(p))
            actionError = nil
            await load()
        } catch {
            actionError = ErrorCopy.message(for: error, fallback: "Couldn’t duplicate \(p.name).")
        }
    }

    private func delete(_ p: QualityProfileRecord) async {
        guard let client = model.client else { return }
        do {
            try await client.deleteQualityProfile(id: p.id)
            actionError = nil
            await load()
        } catch {
            actionError = ErrorCopy.message(for: error, fallback: "Couldn’t delete \(p.name). It may still be in use.")
        }
    }
}

enum QualityProfileEditTarget: Identifiable {
    case new
    case edit(QualityProfileRecord)

    var id: Int { if case .edit(let p) = self { return p.id }; return -1 }
    var profile: QualityProfileRecord? { if case .edit(let p) = self { return p }; return nil }
}
