import SwiftUI
import FusionhaKit

/// The live tester under the editor (web `CfLiveTester`): each test release is
/// scored by the real engine (`POST /customformats/test`), debounced as you
/// type and re-queried after every save. The verdict is about the SAVED
/// format open in the editor; every matched format shows as a chip.
struct CfLiveTesterSections: View {
    let formatName: String
    let savedTick: Int
    @Environment(AppModel.self) private var model
    @State private var titles = [
        "FROM.S04E01.The.Arrival.1080p.AMZN.WEB-DL.DDP5.1.H.264-Kitsune",
        "FROM.S04E01.The.Arrival.1080p.Bluray.x265-RANDOM",
    ]
    @State private var profiles: [QualityProfile] = []
    @State private var profileId: Int?
    @State private var originalLanguage: String?
    @State private var results: [CFTestResult] = []
    @State private var error: String?

    private var trimmed: [String] { titles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
    private var queryKey: String {
        "\(trimmed.filter { !$0.isEmpty }.joined(separator: "\n"))|\(profileId ?? -1)|\(originalLanguage ?? "")|\(savedTick)"
    }

    var body: some View {
        Section {
            Text("Paste release names — each is parsed and scored by the real engine. Results reflect the **saved** format: **saves apply live**.")
                .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            CfProfilePicker(label: "Profile", profiles: profiles, selection: $profileId)
            CfOriginalLanguagePicker(label: "Original", selection: $originalLanguage)
        } header: {
            HStack {
                Text("Live Test").textCase(nil)
                Spacer()
                Text("REAL-TIME").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.done)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.mut)
        }
        .listRowBackground(Theme.card)
        .task { await loadProfiles() }
        .task(id: queryKey) { await run() }
        ForEach(titles.indices, id: \.self) { i in
            Section {
                TextField("Test release \(i + 1)", text: titleBinding(i), axis: .vertical)
                    .font(.system(size: 12.5, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(1...3)
                CfLiveVerdict(result: result(for: i), formatName: formatName)
                Button("Remove test release", systemImage: "xmark", role: .destructive) {
                    if titles.indices.contains(i) { titles.remove(at: i) }
                }
                .font(.system(size: 13))
            }
            .listRowBackground(Theme.card)
        }
        Section {
            Button("Add a test release", systemImage: "plus") { titles.append("") }
            if let error { FormatsErrorRow(message: error) }
        }
        .listRowBackground(Theme.card)
    }

    private func titleBinding(_ i: Int) -> Binding<String> {
        Binding(get: { titles.indices.contains(i) ? titles[i] : "" },
                set: { if titles.indices.contains(i) { titles[i] = $0 } })
    }

    private func result(for i: Int) -> CFTestResult? {
        guard trimmed.indices.contains(i) else { return nil }
        let title = trimmed[i]
        return results.first { $0.title == title }
    }

    private func loadProfiles() async {
        guard let client = model.client, profiles.isEmpty else { return }
        profiles = (try? await client.qualityProfiles()) ?? []
        if profileId == nil { profileId = profiles.first?.id }
    }

    private func run() async {
        let list = trimmed.filter { !$0.isEmpty }
        guard let client = model.client, let profileId, !list.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        do {
            results = try await client.testCustomFormats(titles: list, qualityProfileId: profileId,
                                                         originalLanguage: originalLanguage).results
            error = nil
        } catch {
            if !Task.isCancelled { self.error = ErrorCopy.message(for: error, fallback: "Couldn’t score the test releases.") }
        }
    }
}

/// MATCH / NO MATCH for the format in the editor, its score, and every matched chip.
private struct CfLiveVerdict: View {
    let result: CFTestResult?
    let formatName: String

    var body: some View {
        let entry = result?.matched.first(where: { $0.name == formatName })
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if result != nil {
                    FetchPill(text: entry != nil ? "MATCH" : "NO MATCH", tone: entry != nil ? .ok : .err)
                    Text(formatName).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if let entry { Text(CFLibrary.score(entry.score)).font(.system(size: 12, weight: .bold).monospacedDigit()) }
                    Spacer(minLength: 0)
                } else {
                    FetchPill(text: "·")
                }
            }
            if let result {
                if result.matched.isEmpty {
                    Text("No custom formats matched.").font(.system(size: 12)).foregroundStyle(Theme.dim)
                } else {
                    HStack {
                        Text(entry == nil ? "Other formats that matched" : "All matched formats")
                        Spacer()
                        Text("total \(CFLibrary.score(result.matchedTotal))").monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
                    FetchFlow(spacing: 5, lineSpacing: 5) {
                        ForEach(result.matched, id: \.name) { m in
                            CfScoreChip(name: m.name, score: m.score, highlighted: m.name == formatName)
                        }
                    }
                }
            }
        }
    }
}
