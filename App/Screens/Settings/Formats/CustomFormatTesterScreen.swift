import SwiftUI
import FusionhaKit

/// The full Custom Format Tester (web `CustomFormatTesterPanel`): paste or load
/// release names, pick a profile, and score them — the same parse → score →
/// decision the search path runs, grabbing nothing. The top-scoring accepted
/// release is marked Winner.
struct CustomFormatTesterScreen: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var profiles: [QualityProfile] = []
    @State private var profileId: Int?
    @State private var originalLanguage: String?
    @State private var library: [MediaItem] = []
    @State private var results: [CFTestResult]?
    @State private var testing = false
    @State private var loading = false
    @State private var error: String?

    private var titles: [String] {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        FormatsSubpage(title: "Custom Format Tester") {
            Section("Release names") {
                TextField("One release name per line…", text: $text, axis: .vertical)
                    .font(.system(size: 12.5, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(4...12)
                    .accessibilityLabel("Release names")
                loadMenu
            }
            .listRowBackground(Theme.card)
            Section {
                CfProfilePicker(label: "Quality profile", profiles: profiles, selection: $profileId)
                CfOriginalLanguagePicker(label: "Original language", selection: $originalLanguage)
                Button(testing ? "Testing…" : "Test") { Task { await runTest() } }
                    .disabled(profileId == nil || titles.isEmpty || testing)
            }
            .listRowBackground(Theme.card)
            if let error { Section { FormatsErrorRow(message: error) } }
            if let results {
                if results.isEmpty {
                    Section { Text("No releases scored — nothing to show.").foregroundStyle(Theme.mut) }
                } else {
                    ForEach(results.indices, id: \.self) { i in CfTesterResultSection(result: results[i]) }
                }
            }
        }
        .task { await loadPickers() }
    }

    private var loadMenu: some View {
        Menu {
            ForEach(RecentReleaseSource.allCases, id: \.self) { source in
                Button(source.label) { Task { await load(source, itemId: nil) } }
            }
            Menu("Pick an item…") {
                ForEach(library) { item in
                    Button(item.title) { Task { await load(.grab, itemId: item.id) } }
                }
            }
        } label: {
            Label(loading ? "Loading…" : "Load test data from the app", systemImage: "tray.and.arrow.down")
        }
        .disabled(loading)
    }

    private func loadPickers() async {
        guard let client = model.client else { return }
        if profiles.isEmpty {
            profiles = (try? await client.qualityProfiles()) ?? []
            if profileId == nil { profileId = profiles.first?.id }
        }
        if library.isEmpty { library = (try? await client.library()) ?? [] }
    }

    private func load(_ source: RecentReleaseSource, itemId: Int?) async {
        guard let client = model.client else { return }
        loading = true
        defer { loading = false }
        do {
            text = try await client.recentReleases(source: source, itemId: itemId).titles.joined(separator: "\n")
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load test data.")
        }
    }

    private func runTest() async {
        guard let client = model.client, let profileId, !titles.isEmpty else { return }
        testing = true
        defer { testing = false }
        do {
            results = try await client.testCustomFormats(titles: titles, qualityProfileId: profileId,
                                                         originalLanguage: originalLanguage).results
            error = nil
        } catch {
            self.error = "Test failed — check the release names and try again."
        }
    }
}

/// One scored release: parsed chips, matched-format chips, total, verdict.
private struct CfTesterResultSection: View {
    let result: CFTestResult

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Text(result.title).font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
                if result.best { FetchPill(text: "Winner", tone: .accent) }
            }
            FetchFlow(spacing: 5, lineSpacing: 5) {
                ForEach(Array(result.parsed.chips.enumerated()), id: \.offset) { pair in FetchChip(text: pair.element) }
            }
            if result.matched.isEmpty {
                Text("No custom formats matched.").font(.system(size: 12)).foregroundStyle(Theme.dim)
            } else {
                FetchFlow(spacing: 5, lineSpacing: 5) {
                    ForEach(result.matched, id: \.name) { m in CfScoreChip(name: m.name, score: m.score) }
                }
            }
            HStack(spacing: 8) {
                Text("Total score").font(.system(size: 12)).foregroundStyle(Theme.mut)
                Text(CFLibrary.score(result.total)).font(.system(size: 13, weight: .bold).monospacedDigit())
                Spacer(minLength: 0)
                if !result.accepted, let reason = result.reason, !reason.isEmpty {
                    Text(reason).font(.system(size: 11.5)).foregroundStyle(Theme.danger).lineLimit(2)
                }
                FetchPill(text: result.verdictLabel, tone: result.accepted ? .ok : .err)
            }
        }
        .listRowBackground(result.best ? Theme.done.opacity(0.10) : Theme.card)
    }
}

/// The tester's quality-profile picker (scores against one profile).
struct CfProfilePicker: View {
    let label: String
    let profiles: [QualityProfile]
    @Binding var selection: Int?

    var body: some View {
        Picker(label, selection: $selection) {
            if selection == nil { Text("Select a profile").tag(Int?.none) }
            ForEach(profiles) { p in Text(p.name).tag(Optional(p.id)) }
        }
        .pickerStyle(.menu)
        .tint(Theme.mut)
        .accessibilityLabel(label == "Profile" ? "Tester quality profile" : "Quality profile")
    }
}

/// The optional "Original language" a release's Original tag resolves to.
struct CfOriginalLanguagePicker: View {
    let label: String
    @Binding var selection: String?

    var body: some View {
        Picker(label, selection: $selection) {
            Text("No original language").tag(String?.none)
            ForEach(CFOriginalLanguages.all.indices, id: \.self) { i in
                Text(CFOriginalLanguages.all[i].name).tag(Optional(CFOriginalLanguages.all[i].code))
            }
        }
        .pickerStyle(.menu)
        .tint(Theme.mut)
    }
}
