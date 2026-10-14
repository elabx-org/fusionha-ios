import SwiftUI
import FusionhaKit

/// "Block release group?" (the web's `BlockGroupDialog`): offered after a
/// proven fake from a group. Skip it for this title (default), everywhere, or
/// only this release; or "Not now" (30 days). Needs `integrations.manage`.
struct BlockReleaseGroupSheet: View {
    let group: String
    let mediaItemId: Int
    let title: String
    let claimedResolution: Int?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var scope: HeldCopy.BlockScope = .item
    @State private var customFormat = false
    @State private var evidence: ReleaseGroupEvidence?
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let evidence {
                        Text("\(evidence.mislabeledCount) of \(evidence.probedCount) probed \(group) releases were fakes.")
                            .font(.subheadline).foregroundStyle(Theme.mut)
                    }
                    Picker("Block", selection: $scope) {
                        ForEach(HeldCopy.BlockScope.allCases, id: \.self) {
                            Text(HeldCopy.scopeLabel($0, group: group, title: title)).tag($0)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                if scope != .release {
                    Section {
                        Toggle("Add a custom format", isOn: $customFormat)
                    } footer: {
                        if let res = claimedResolution {
                            Text("Scores \(HeldCopy.customFormatName(group: group, claimedResolution: res)) in your quality profiles.")
                        }
                    }
                }
                Section("What this will do") {
                    ForEach(lines, id: \.self) { Text($0).font(.subheadline) }
                }
                Section {
                    Button("Not now") { Task { await decide(notNow: true) } }
                        .disabled(working)
                } footer: {
                    Text(HeldCopy.notNowNote)
                }
                if let error {
                    Text(error).foregroundStyle(Theme.danger).font(.footnote)
                }
            }
            .navigationTitle("Block release group?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(scope == .release ? "Confirm" : "Block") { Task { await confirm() } }
                        .disabled(working)
                }
            }
            .task { await loadEvidence() }
        }
        .presentationDetents([.medium, .large])
    }

    private var lines: [String] {
        HeldCopy.consequences(scope, group: group, title: title,
                              otherTitles: evidence?.otherTitles.map(\.title) ?? [],
                              withCustomFormat: customFormat && scope != .release)
    }

    private func loadEvidence() async {
        evidence = try? await model.client?.releaseGroupEvidence(group: group, mediaItemId: mediaItemId)
    }

    private func confirm() async {
        guard scope != .release else { return await decide(notNow: false) }
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            _ = try await client.blockReleaseGroup(group, scope: scope, mediaItemId: mediaItemId, createCustomFormat: customFormat)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            model.toast(HeldCopy.scopeLabel(scope, group: group, title: title), title: "Release group blocked", variant: .success)
            dismiss()
        } catch {
            self.error = HeldCopy.errorMessage(error)
        }
    }

    private func decide(notNow: Bool) async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            try await client.releaseGroupPromptDecision(group, mediaItemId: mediaItemId, notNow: notNow)
            dismiss()
        } catch {
            self.error = HeldCopy.errorMessage(error)
        }
    }
}
