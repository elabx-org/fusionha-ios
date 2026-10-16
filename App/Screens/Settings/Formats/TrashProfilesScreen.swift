import SwiftUI
import FusionhaKit

/// TRaSH Guides › Profiles (web `ProfilesTab`): the guide's recommended quality
/// profiles for the Media choice — tick any subset and import them, or one
/// profile at a time. "Added" is server-computed per kind-suffixed name. Anime
/// also carries the four score-nudge preferences.
struct TrashProfilesScreen: View {
    @Binding var category: TrashCategory
    let counts: [TrashCategory: Int]
    @Environment(AppModel.self) private var model
    @State private var guides: TrashGuides?
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        FormatsSubpage(title: "Profiles") {
            Section { TrashMediaPicker(category: $category, counts: counts) }
            if !selected.isEmpty {
                Section {
                    HStack {
                        Text("**\(selected.count)** selected").foregroundStyle(Theme.txt)
                        Spacer()
                        Button("Import selected (\(selected.count))") { Task { await importNames(Array(selected).sorted()) } }
                            .buttonStyle(.web(.primary))
                            .disabled(busy)
                    }
                }
                .listRowBackground(Theme.card)
            }
            Section {
                if let guides {
                    if guides.profiles.isEmpty {
                        Text("No recommended profiles for this selection.").foregroundStyle(Theme.mut)
                    }
                    ForEach(guides.profiles, id: \.name) { profile in row(profile) }
                } else if error == nil {
                    Text("Loading guide profiles…").foregroundStyle(Theme.mut)
                }
                if let error { FormatsErrorRow(message: error) }
            }
            .listRowBackground(Theme.card)
            if category == .anime { TrashAnimePreferencesSection() }
        }
        .task(id: category) { await load() }
    }

    private func row(_ profile: TrashProfileSummary) -> some View {
        let done = profile.added ?? false
        let description = TrashText.plain(profile.description)
        return HStack(alignment: .top, spacing: 10) {
            if !done {
                Button { toggle(profile.name) } label: {
                    Image(systemName: selected.contains(profile.name) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected.contains(profile.name) ? Theme.i1 : Theme.dim)
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .accessibilityLabel("Select \(profile.name)")
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                    CfSourceBadge(source: "trash")
                }
                Text((description.isEmpty ? "\(profile.count ?? 0) formats" : description)
                     + (profile.cutoff.map { $0.isEmpty ? "" : " · cutoff \(DetailText.quality($0))" } ?? ""))
                    .font(.caption).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            if done {
                Label("Added", systemImage: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(Theme.done)
            } else {
                Button("Import") { Task { await importNames([profile.name]) } }
                    .buttonStyle(.web(.primary))
                    .disabled(busy)
                    .accessibilityLabel("Import \(profile.name) profile")
            }
        }
    }

    private func toggle(_ name: String) {
        if selected.contains(name) { selected.remove(name) } else { selected.insert(name) }
    }

    private func load() async {
        guard let client = model.client else { return }
        selected = []
        guides = nil
        do {
            guides = try await client.trashGuides(category)
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the guide profiles.")
        }
    }

    private func importNames(_ names: [String]) async {
        guard let client = model.client, !names.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await client.trashImportProfiles(category, names: names)
            selected = []
            guides = try? await client.trashGuides(category)
        } catch {
            self.error = error.settingsMessage
        }
    }
}

/// The four anime toggles that nudge the imported anime scores, applied
/// override-safe by `PUT /trash/anime-preferences`.
private struct TrashAnimePreferencesSection: View {
    @Environment(AppModel.self) private var model
    @State private var prefs: TrashAnimePreferences?
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        Section {
            ForEach(TrashAnimePreferences.fields.indices, id: \.self) { i in
                let field = TrashAnimePreferences.fields[i]
                Toggle(isOn: binding(field.key)) { FieldLabel(label: field.label, description: field.hint) }
                    .tint(Theme.i1)
                    .disabled(prefs == nil || saving)
            }
            if let error { FormatsErrorRow(message: error) }
        } header: {
            Text("Anime preferences · nudge the imported scores").textCase(nil)
        }
        .listRowBackground(Theme.card)
        .task { await load() }
    }

    private func binding(_ key: String) -> Binding<Bool> {
        Binding(get: { prefs?.value(key) ?? false },
                set: { on in if let prefs { Task { await save(prefs.setting(key, on)) } } })
    }

    private func load() async {
        guard let client = model.client else { return }
        prefs = try? await client.trashAnimePreferences()
    }

    private func save(_ next: TrashAnimePreferences) async {
        guard let client = model.client else { return }
        let before = prefs
        prefs = next
        saving = true
        defer { saving = false }
        do {
            prefs = try await client.updateTrashAnimePreferences(next)
            error = nil
        } catch {
            prefs = before
            self.error = error.settingsMessage
        }
    }
}
