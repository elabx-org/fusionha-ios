import SwiftUI
import FusionhaKit

// Settings → Default Profiles and Release Filters.

// MARK: Default Profiles

/// The kind × tier matrix the Add flow and Library Import read (the web's
/// `DefaultProfilesPanel.tsx`), plus the movie minimum-availability default.
/// The matrix saves with "Save defaults" (`PUT /api/v1/config/add-defaults`);
/// the availability picker autosaves.
struct DefaultProfilesSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @State private var cells: [String: Cell]?
    @State private var profiles: [QualityProfile] = []
    @State private var roots: [RootFolder] = []
    @State private var saving = false
    @State private var saved = false
    @State private var error: String?

    struct Cell: Equatable {
        var profile: Int?
        var root: Int?
    }

    private static let kinds = [("movie", "Movies"), ("series", "Series"), ("anime", "Anime")]
    private static let tiers: [QualityTier] = [.hd, .uhd]
    private static let unset = "— (use smart default)"

    var body: some View {
        SettingsForm(slug: "defaultprofiles") {
            SettingsSection("How it works") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Every title has a **kind** (Movies / Series / Anime) and a **tier** (HD·1080p / UHD·4K). Whenever fusionha creates a title or edition, it looks up this table by that kind × tier and applies the cell's **quality profile**.")
                    Text("Two things create titles: the **Add flow** (Overseerr / Seer, or the Add dialog) — which also drops the new title into the cell's **root folder**; and **Library Import** — which applies the profile but keeps the folder it's adopting. Because the match is by kind + tier, it works for **any root, even one you haven't added yet**.")
                    Text("Set a cell to a specific profile to pin it, or leave it on `— (use smart default)` to let fusionha pick the first profile of that kind.")
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
            }

            SettingsSection("Default minimum availability (Movies)",
                            footer: "New movies default to this availability gate (Radarr's Minimum Availability). Released = only grab once the home-media date has passed.") {
                SettingPicker(label: "Minimum availability", options: [("announced", "Announced"), ("inCinemas", "In Cinemas"), ("released", "Released")],
                              selection: store.stringBinding("default_movie_minimum_availability", "released"))
            }

            if let cells {
                ForEach(Self.kinds, id: \.0) { kind in
                    SettingsSection(kind.1) {
                        ForEach(Self.tiers, id: \.self) { tier in
                            cellRows(kind: kind.0, kindLabel: kind.1, tier: tier, cell: cells[key(kind.0, tier)] ?? Cell())
                        }
                    }
                }
                Section {
                    HStack(spacing: 10) {
                        Button(saving ? "Saving…" : "Save defaults") { Task { await save() } }
                            .buttonStyle(.web(.primary))
                            .disabled(saving)
                        if saved {
                            Label("Saved", systemImage: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.done)
                                .transition(.opacity)
                        }
                        if let error {
                            Text(error).font(.system(size: 12)).foregroundStyle(Theme.danger)
                        }
                    }
                } footer: {
                    Text("A cell left on `— (use smart default)` keeps the automatic guess: Library Import falls back to the **first profile of that kind** (never a cross-kind one), and the Add flow keeps its heuristic root. Anime titles use the Anime row; a series detected as anime resolves to Anime before Series.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            } else {
                SettingsLoadingRow(error: error)
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func cellRows(kind: String, kindLabel: String, tier: QualityTier, cell: Cell) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(tier.color).frame(width: 7, height: 7)
                Text(tier.chipLabel).font(.system(size: 12, weight: .bold)).foregroundStyle(tier.color)
            }
            pickerRow(title: "Quality profile", tag: "Add + Import", tagColor: Theme.cyan,
                      selection: binding(kind, tier, \.profile),
                      options: profilesFor(kind).map { ($0.id, $0.name) })
                .accessibilityLabel("Quality profile · \(kindLabel) · \(tier.chipLabel)")
            pickerRow(title: "Root folder", tag: "Add flow", tagColor: Theme.edition,
                      selection: binding(kind, tier, \.root),
                      options: roots.map { ($0.id, $0.path) })
                .accessibilityLabel("Root folder · \(kindLabel) · \(tier.chipLabel)")
        }
        .padding(.vertical, 4)
        .settingsField(tier == .hd ? "Quality profile" : "Root folder")
    }

    private func pickerRow(title: String, tag: String, tagColor: Color, selection: Binding<Int?>, options: [(Int, String)]) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                Text(tag)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(tagColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(tagColor.opacity(0.4)))
            }
            Spacer()
            Picker(title, selection: selection) {
                Text(Self.unset).tag(Int?.none)
                ForEach(options.indices, id: \.self) { i in
                    Text(options[i].1).tag(Int?.some(options[i].0))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Theme.mut)
        }
    }

    private func key(_ kind: String, _ tier: QualityTier) -> String { "\(kind):\(tier.rawValue)" }

    private func binding(_ kind: String, _ tier: QualityTier, _ path: WritableKeyPath<Cell, Int?>) -> Binding<Int?> {
        Binding(get: { cells?[key(kind, tier)]?[keyPath: path] },
                set: { value in
                    var cell = cells?[key(kind, tier)] ?? Cell()
                    cell[keyPath: path] = value
                    cells?[key(kind, tier)] = cell
                    saved = false
                })
    }

    /// Anime: unscoped + anime profiles; movies/series: unscoped + that kind.
    private func profilesFor(_ kind: String) -> [QualityProfile] {
        profiles.filter { $0.mediaKind == nil || $0.mediaKind == kind }
    }

    private func load() async {
        guard let client = store.client else { return }
        do {
            async let slots = client.addDefaults()
            async let p = client.qualityProfiles()
            async let r = client.rootFolders()
            let (s, ps, rs) = try await (slots, p, r)
            profiles = ps
            roots = rs
            var next: [String: Cell] = [:]
            for slot in s {
                if let tier = QualityTier(rawValue: slot.tier.rawValue) {
                    next[key(slot.profileKind, tier)] = Cell(profile: slot.qualityProfileId, root: slot.rootFolderId)
                }
            }
            cells = next
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save() async {
        guard let client = store.client, let cells else { return }
        saving = true
        defer { saving = false }
        var slots: [JSONValue] = []
        for kind in Self.kinds {
            for tier in Self.tiers {
                let cell = cells[key(kind.0, tier)] ?? Cell()
                slots.append(.object([
                    "profile_kind": .string(kind.0),
                    "tier": .string(tier.rawValue),
                    "quality_profile_id": cell.profile.map { .number(Double($0)) } ?? .null,
                    "root_folder_id": cell.root.map { .number(Double($0)) } ?? .null,
                ]))
            }
        }
        do {
            try await client.json("PUT", "/api/v1/config/add-defaults", body: .object(["defaults": .array(slots)]))
            error = nil
            withAnimation(.easeOut(duration: 0.2)) { saved = true }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: Release Filters

/// Required / Rejected release-name terms (the web's `ReleaseFiltersPanel.tsx`)
/// with a live tester. `GET/POST/PUT/DELETE /api/v1/release-term-filters`,
/// `POST /api/v1/release-term-filters/test`.
struct ReleaseFiltersSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var rows: [JSONRecord]?
    @State private var loadError: String?
    @State private var drafts: [String: String] = [:]
    @State private var testTitle = ""
    @State private var verdict: (accepted: Bool, reason: String?)?

    private static let base = "/api/v1/release-term-filters"

    var body: some View {
        SettingsForm(slug: "releasefilters") {
            Section {
                Text("Reject releases by their name *before* they're grabbed — the arr “Release Profile” equivalent. Applies to every automatic grab (search, RSS, season packs). Plain text is a case-insensitive substring; wrap in `/…/` for a regex. Rejected extensions live under **Media Management → File Management**.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

            if let loadError {
                SettingsLoadingRow(error: "Couldn't load the release filters. Check the backend and try again. (\(loadError))")
            } else if let rows {
                termSection(kind: "required", rows: rows.filter { $0["kind"]?.string == "required" })
                termSection(kind: "rejected", rows: rows.filter { $0["kind"]?.string == "rejected" })
                testSection
            } else {
                SettingsLoadingRow()
            }
        }
        .task { await load() }
    }

    private func termSection(kind: String, rows: [JSONRecord]) -> some View {
        let required = kind == "required"
        let color = required ? Theme.done : Theme.danger
        return Section {
            if rows.isEmpty {
                Text("None yet.").font(.system(size: 13)).foregroundStyle(Theme.dim)
            }
            ForEach(rows) { row in
                termRow(row)
                    .swipeActions {
                        Button(role: .destructive) { Task { await delete(row) } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .transition(motionOff ? .identity : .opacity)
            }
            HStack(spacing: 8) {
                TextField("", text: draftBinding(kind),
                          prompt: Text("Add a \(kind) term — plain text, or /regex/ …").foregroundStyle(Theme.dim))
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { Task { await add(kind) } }
                    .accessibilityLabel("Add a \(kind) term")
                Button("Add") { Task { await add(kind) } }
                    .buttonStyle(.web())
                    .disabled((drafts[kind] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(required ? "Required terms" : "Rejected terms")
                    .font(.system(size: 12.5, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.mut)
                Spacer()
                Text(required ? "release must match at least one" : "release must not match any")
                    .font(.system(size: 11.5))
                    .textCase(nil)
                    .foregroundStyle(Theme.dim)
            }
        }
        .listRowBackground(Theme.card)
        .settingsField(required ? "Required terms" : "Rejected terms")
    }

    private func termRow(_ row: JSONRecord) -> some View {
        let term = row["term"]?.string ?? ""
        let enabled = row["enabled"]?.bool ?? true
        return HStack(spacing: 8) {
            Text(term)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(enabled ? Theme.txt : Theme.dim)
                .lineLimit(1)
            if isRegex(term) {
                Text("regex")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Theme.edition)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.edition.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
            Spacer()
            Toggle("", isOn: Binding(get: { enabled }, set: { value in Task { await setEnabled(row, value) } }))
                .labelsHidden()
                .tint(Theme.indigo)
                .accessibilityLabel("Enable \(term)")
            Button { Task { await delete(row) } } label: {
                Image(systemName: "trash").font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.mut)
            .accessibilityLabel("Delete \(term)")
        }
    }

    private var testSection: some View {
        Section {
            TextField("", text: $testTitle, prompt: Text("Paste a release name to check…").foregroundStyle(Theme.dim))
                .font(.system(size: 13, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Release name to test")
            if let verdict {
                Label(verdict.accepted ? "Would be grabbed" : "Rejected · \(verdict.reason ?? "")",
                      systemImage: verdict.accepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(verdict.accepted ? Theme.done : Theme.danger)
                    .transition(.opacity)
            }
        } header: {
            HStack(spacing: 7) {
                Circle().fill(Theme.cyan).frame(width: 7, height: 7)
                Text("Test a release title")
                    .font(.system(size: 12.5, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.mut)
            }
        }
        .listRowBackground(Theme.card)
        .settingsField("Test a release title")
        .task(id: testTitle) {
            // Debounced like the web (300ms); a newer title cancels this one.
            verdict = nil
            let title = testTitle.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let client = store.client,
                  let result = try? await client.json("POST", "\(Self.base)/test", body: .object(["title": .string(title)])),
                  !Task.isCancelled else { return }
            withAnimation(motionOff ? nil : .easeOut(duration: 0.15)) {
                verdict = (result["accepted"]?.bool ?? false, result["reason"]?.string)
            }
        }
    }

    private func isRegex(_ term: String) -> Bool {
        let t = term.trimmingCharacters(in: .whitespaces)
        return t.count > 2 && t.hasPrefix("/") && t.hasSuffix("/")
    }

    private func draftBinding(_ kind: String) -> Binding<String> {
        Binding(get: { drafts[kind] ?? "" }, set: { drafts[kind] = $0 })
    }

    private func load() async {
        guard let client = store.client else { return }
        do {
            rows = try await client.records(Self.base)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func add(_ kind: String) async {
        let term = (drafts[kind] ?? "").trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, let client = store.client else { return }
        do {
            try await client.json("POST", Self.base, body: .object(["term": .string(term), "kind": .string(kind)]))
            drafts[kind] = ""
            await reload()
        } catch {
            store.saveError = error.localizedDescription
        }
    }

    private func setEnabled(_ row: JSONRecord, _ enabled: Bool) async {
        guard let client = store.client else { return }
        if let i = rows?.firstIndex(where: { $0.id == row.id }) { rows?[i]["enabled"] = .bool(enabled) }
        do {
            try await client.json("PUT", "\(Self.base)/\(row.id)", body: .object(["enabled": .bool(enabled)]))
        } catch {
            store.saveError = error.localizedDescription
            await reload()
        }
    }

    private func delete(_ row: JSONRecord) async {
        guard let client = store.client else { return }
        do {
            try await client.json("DELETE", "\(Self.base)/\(row.id)")
            SettingsMotion.perform(motionOff) { rows?.removeAll { $0.id == row.id } }
        } catch {
            store.saveError = error.localizedDescription
        }
    }

    private func reload() async {
        guard let client = store.client, let fresh = try? await client.records(Self.base) else { return }
        SettingsMotion.perform(motionOff) { rows = fresh }
    }
}
