import SwiftUI
import FusionhaKit

/// Custom Formats › Import (web `CfImportPanel`): pull custom formats + scored
/// quality profiles from a live Sonarr/Radarr (tagged `source: arr`), or apply
/// a bundled arr-capture preset with no network (`source: preset`).
struct CustomFormatImportScreen: View {
    var onImported: () async -> Void = {}
    @State private var mode = "arr"

    var body: some View {
        FormatsSubpage(title: "Import custom formats") {
            Section {
                Text("Bring your **tuned custom formats + scored quality profiles** in from a live arr, or apply a bundled preset. Imported items are tagged with their **source** so they stay distinct from manual + TRaSH formats and survive a TRaSH re-sync.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                Picker("Import source", selection: $mode) {
                    Text("From an arr").tag("arr")
                    Text("Bundled preset").tag("preset")
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.card)
            if mode == "arr" {
                CfArrImportSections(onImported: onImported)
            } else {
                CfPresetImportSections(onImported: onImported)
            }
        }
    }
}

/// Mode 1: read a live Sonarr/Radarr. Test is a zero-write probe; the key is sent once.
private struct CfArrImportSections: View {
    let onImported: () async -> Void
    @Environment(AppModel.self) private var model
    @State private var kind = "sonarr"
    @State private var url = ""
    @State private var apiKey = ""
    @State private var importCfs = true
    @State private var importProfiles = true
    @State private var overwrite = false
    @State private var testing = false
    @State private var importing = false
    @State private var testOk: Bool?
    @State private var message: String?
    @State private var result: ArrCfImportResult?

    private var valid: Bool { !url.trimmingCharacters(in: .whitespaces).isEmpty && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }
    private var arrName: String { kind == "sonarr" ? "Sonarr" : "Radarr" }
    private var mediaKind: String { CfImportText.arrMediaKind(kind) }

    var body: some View {
        Section {
            Picker("Source", selection: $kind) {
                Text("Sonarr").tag("sonarr")
                Text("Radarr").tag("radarr")
            }
            .pickerStyle(.segmented)
            TextField("URL", text: $url, prompt: Text(kind == "sonarr" ? "http://sonarr:8989" : "http://radarr:7878"))
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("API key", text: $apiKey, prompt: Text("your arr API key"))
            HStack {
                Button(testing ? "Testing…" : "Test") { Task { await run(test: true) } }
                    .disabled(!valid || testing)
                Spacer()
                if testOk == true { Text("Connected · reachable").font(.system(size: 12.5)).foregroundStyle(Theme.done) }
            }
            if testOk == false, let message { FormatsErrorRow(message: message) }
        }
        .listRowBackground(Theme.card)
        Section {
            Toggle(isOn: $importCfs) { FieldLabel(label: "Custom formats", description: "specs + names → \(mediaKind)") }
            Toggle(isOn: $importProfiles) {
                FieldLabel(label: "Quality profiles", description: "with their CF scores + cutoff → \(mediaKind)")
            }
            Toggle(isOn: $overwrite) {
                FieldLabel(label: "Overwrite existing", description: "replace same-name items (off = skip duplicates)")
            }
        } header: {
            Text("Choose what to bring in — mapped onto fusionha and scored like the arrs.").textCase(nil)
        }
        .tint(Theme.i1)
        .listRowBackground(Theme.card)
        Section {
            Button(importing ? "Importing…" : "Import from \(arrName)") { Task { await run(test: false) } }
                .disabled(!valid || (!importCfs && !importProfiles) || importing)
            if testOk == nil, let message { FormatsErrorRow(message: message) }
            if let result {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Imported from \(result.kind)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.done)
                    Text(result.section.summary).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
            }
        } footer: {
            Text("tagged source: arr")
        }
        .listRowBackground(Theme.card)
    }

    private func run(test: Bool) async {
        guard valid, let client = model.client else { return }
        if test { testing = true } else { importing = true }
        defer { testing = false; importing = false }
        message = nil
        if test { result = nil } else { testOk = nil }
        do {
            let r = try await client.importCustomFormatsFromArr(
                kind: kind, url: url.trimmingCharacters(in: .whitespaces), apiKey: apiKey,
                importCfs: test ? false : importCfs, importProfiles: test ? false : importProfiles,
                overwrite: test ? false : overwrite)
            if test { testOk = true } else { result = r; await onImported() }
        } catch {
            if test { testOk = false }
            message = error.settingsMessage
        }
    }
}

/// Mode 2: apply a bundled arr-capture preset (no network).
private struct CfPresetImportSections: View {
    let onImported: () async -> Void
    @Environment(AppModel.self) private var model
    @State private var presets: [BundledPresetSummary]?
    @State private var overwrite = false
    @State private var pending: String?
    @State private var result: BundledPresetResult?
    @State private var error: String?

    var body: some View {
        Section {
            Toggle(isOn: $overwrite) {
                FieldLabel(label: "Overwrite existing", description: "replace same-name items (off = skip duplicates)")
            }
            .tint(Theme.i1)
        }
        .listRowBackground(Theme.card)
        Section {
            if let presets {
                if presets.isEmpty { Text("No bundled presets available.").foregroundStyle(Theme.mut) }
                ForEach(presets) { preset in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                            ForEach(preset.chips, id: \.self) { Text($0).font(.caption).foregroundStyle(Theme.mut) }
                        }
                        Spacer()
                        Button(pending == preset.name ? "Applying…" : "Apply") { Task { await apply(preset.name) } }
                            .buttonStyle(.web(.primary))
                            .disabled(pending != nil)
                            .accessibilityLabel("Apply \(preset.name)")
                    }
                }
            } else {
                Text("Loading presets…").foregroundStyle(Theme.mut)
            }
            if let error { FormatsErrorRow(message: error) }
            if let result {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Applied \(result.name)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.done)
                    ForEach(result.sections, id: \.mediaKind) { Text($0.summary).font(.system(size: 12.5)).foregroundStyle(Theme.mut) }
                }
            }
        } footer: {
            Text("tagged source: preset")
        }
        .listRowBackground(Theme.card)
        .task { await load() }
    }

    private func load() async {
        guard let client = model.client, presets == nil else { return }
        do { presets = try await client.bundledCfPresets() } catch {
            presets = []
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the bundled presets.")
        }
    }

    private func apply(_ name: String) async {
        guard let client = model.client else { return }
        pending = name
        defer { pending = nil }
        do {
            result = try await client.applyBundledCfPreset(name: name, overwrite: overwrite)
            error = nil
            await onImported()
        } catch {
            self.error = error.settingsMessage
        }
    }
}
