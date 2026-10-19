import SwiftUI
import FusionhaKit

/// The capture surface behind Presets › Re-import (web `ArrConnectionsCard`):
/// saved Sonarr/Radarr connections, each with Test (system status + version)
/// and Capture (read the named profile into a preset), plus Add connection —
/// tested right after it is saved so a typo surfaces at once.
struct ArrConnectionsSections: View {
    let connections: [ArrConnection]
    let toaster: FetchToaster
    let onChanged: () async -> Void
    @Environment(AppModel.self) private var model
    @State private var adding = false
    @State private var tests: [Int: ConnectionTestResult] = [:]
    @State private var testing: Int?
    @State private var pendingDelete: ArrConnection?

    var body: some View {
        Section {
            if connections.isEmpty {
                Text("No arr connections yet — add your Sonarr/Radarr to capture its profiles.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
            ForEach(connections) { conn in
                ArrConnectionRow(conn: conn, test: tests[conn.id], testing: testing == conn.id, toaster: toaster,
                                 onTest: { Task { await runTest(conn.id) } },
                                 onCaptured: onChanged)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = conn }
                    }
            }
            Button("Add connection", systemImage: "plus") { adding = true }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected arrs").font(.system(size: 15, weight: .semibold))
                Text("capture a tuned profile from a live Sonarr/Radarr").font(.system(size: 12))
            }
            .textCase(nil)
            .foregroundStyle(Theme.mut)
        }
        .listRowBackground(Theme.card)
        .sheet(isPresented: $adding) {
            ArrConnectionAddSheet { id in
                await onChanged()
                await runTest(id)
            }
        }
        .confirmationDialog("Delete \(pendingDelete?.name ?? "this connection")?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let c = pendingDelete { Task { await delete(c) } } }
        } message: {
            Text("Presets it captured stay.")
        }
    }

    private func runTest(_ id: Int) async {
        guard let client = model.client else { return }
        testing = id
        defer { testing = nil }
        do {
            tests[id] = try await client.testArrConnection(id: id)
        } catch {
            tests[id] = ConnectionTestResult(ok: false, message: error.settingsMessage)
        }
    }

    private func delete(_ conn: ArrConnection) async {
        guard let client = model.client else { return }
        do {
            try await client.deleteArrConnection(id: conn.id)
            await onChanged()
        } catch { toaster.error(error) }
    }
}

/// One saved connection: identity, Test result, and the Capture controls.
private struct ArrConnectionRow: View {
    let conn: ArrConnection
    let test: ConnectionTestResult?
    let testing: Bool
    let toaster: FetchToaster
    let onTest: () -> Void
    let onCaptured: () async -> Void
    @Environment(AppModel.self) private var model
    @State private var profileName = ""
    @State private var saveAs = ""
    @State private var asAnime = false
    @State private var capturing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(conn.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                FetchChip(text: conn.flavor)
                Spacer(minLength: 0)
                Button(testing ? "Testing…" : "Test", action: onTest)
                    .buttonStyle(.web(.ghost))
                    .disabled(testing)
                    .accessibilityLabel("Test \(conn.name)")
            }
            MonoText(conn.baseUrl)
            if let test {
                Label(test.ok ? test.message + (test.version.map { " · v\($0)" } ?? "") : test.message,
                      systemImage: test.ok ? "checkmark" : "xmark")
                    .font(.system(size: 12)).foregroundStyle(test.ok ? Theme.done : Theme.danger)
            }
            TextField("Profile name…", text: $profileName)
                .accessibilityLabel("Profile name on \(conn.name)")
            TextField(profileName.trimmingCharacters(in: .whitespaces).isEmpty ? "Save as…" : "Save as \(profileName.trimmingCharacters(in: .whitespaces))",
                      text: $saveAs)
                .accessibilityLabel("Save as (preset name) from \(conn.name)")
            HStack {
                if conn.flavor == "sonarr" {
                    Toggle("anime", isOn: $asAnime).fixedSize().tint(Theme.i1)
                        .accessibilityLabel("Capture from \(conn.name) as anime")
                }
                Spacer()
                Button(capturing ? "Capturing…" : "Capture") { Task { await capture() } }
                    .buttonStyle(.web(.primary))
                    .disabled(capturing || profileName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Capture from \(conn.name)")
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(.vertical, 4)
    }

    private func capture() async {
        let name = profileName.trimmingCharacters(in: .whitespaces)
        guard let client = model.client, !name.isEmpty else { return }
        capturing = true
        defer { capturing = false }
        do {
            let as_ = saveAs.trimmingCharacters(in: .whitespaces)
            let preset = try await client.capturePreset(connectionId: conn.id, profileName: name, asAnime: asAnime,
                                                        saveAs: as_.isEmpty ? nil : as_)
            profileName = ""
            saveAs = ""
            toaster.show("Captured \(preset?.name ?? name) from \(conn.name).")
            await onCaptured()
        } catch { toaster.error(error) }
    }
}

/// Add connection: name, flavor, base URL, API key → "Add & test".
private struct ArrConnectionAddSheet: View {
    let onAdded: (Int) async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var flavor = "sonarr"
    @State private var baseUrl = ""
    @State private var apiKey = ""
    @State private var working = false
    @State private var error: String?

    private var valid: Bool { [name, baseUrl, apiKey].allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Sonarr-4K"))
                    Picker("Flavor", selection: $flavor) {
                        Text("Sonarr").tag("sonarr")
                        Text("Radarr").tag("radarr")
                    }
                    TextField("Base URL", text: $baseUrl, prompt: Text("http://sonarr:8989"))
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("API key", text: $apiKey)
                }
                if let error { Section { FormatsErrorRow(message: error) } }
            }
            .navigationTitle("Add connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add & test", systemImage: "checkmark") { Task { await add() } }.disabled(!valid || working)
                }
            }
        }
    }

    private func add() async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            let conn = try await client.createArrConnection(name: name, baseUrl: baseUrl, apiKey: apiKey, flavor: flavor)
            dismiss()
            await onAdded(conn.id)
        } catch {
            self.error = error.settingsMessage
        }
    }
}
