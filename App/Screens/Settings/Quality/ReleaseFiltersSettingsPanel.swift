import SwiftUI
import FusionhaKit

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
                    .font(.system(size: 11, weight: .bold))
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
                Circle().fill(Theme.i2).frame(width: 7, height: 7)
                Text("Test a release title")
                    .font(.system(size: 12.5, weight: .bold))
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
