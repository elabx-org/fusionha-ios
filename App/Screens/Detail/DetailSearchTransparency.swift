import SwiftUI
import FusionhaKit

/// "Always treat this as <edition> for this title" under an edition-mismatch
/// rejection (LearnEditionAlias.tsx): opens the alias sheet pre-filled with
/// the release's edition term.
struct LearnEditionAliasButton: View {
    @Environment(AppModel.self) private var model
    let release: ReleasePreview
    @State private var open = false

    var body: some View {
        if let mismatch = EditionAliasSuggest.mismatch(release.reason), model.me?.can("edit") ?? true {
            Button("Always treat this as \(mismatch.tracked) for this title") { open = true }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .buttonStyle(.plain)
                .duoPageSheet(isPresented: $open) {
                    LearnEditionAliasSheet(release: release, tracked: mismatch.tracked)
                }
        }
    }
}

private struct LearnEditionAliasSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let release: ReleasePreview
    let tracked: String
    @State private var term = ""
    @State private var guarded = false
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        NavigationStack {
            Form {
                Section {
                    Text(release.title).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.mut)
                        .textSelection(.enabled)
                } footer: {
                    Text("Map this release's term to the \(tracked) edition — only for this title.")
                }
                Section {
                    TextField("e.g. Vrach Frankenshteyn Cut", text: $term)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Release term")
                } footer: {
                    Text("Pre-filled from the release name — check it names only the cut, not part of the title.")
                }
                Section {
                    Toggle("Guarded", isOn: $guarded).tint(Theme.i1)
                } footer: {
                    Text("For a short or ambiguous term. Matches only in a movie release's trailing edition slot.")
                }
                if let error {
                    Section { Text(error).foregroundStyle(Theme.danger) }
                }
            }
            .disabled(saving)
            .navigationTitle("Add edition alias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save alias", systemImage: "checkmark") { Task { await save(trimmed) } }
                        .disabled(trimmed.isEmpty || saving)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { if term.isEmpty { term = EditionAliasSuggest.term(release.title) } }
    }

    private func save(_ trimmed: String) async {
        guard let client = store.client else { return }
        saving = true
        defer { saving = false }
        do {
            try await client.addEditionAlias(itemId: store.itemId, EditionAliasCreate(term: trimmed, edition: tracked, guarded: guarded))
            dismiss()
        } catch {
            self.error = ReleaseSearchErrorText.detail(error) ?? "Could not save alias"
        }
    }
}

/// "Last search passed over: 12 wrong edition · 3 no upgrade …" (InteractiveSearch
/// `SkipReasonChips`): the newest decision pass's rejections for this version,
/// bucketed like the Tasks trail, plus a link to the full trail.
struct SkipReasonChips: View {
    let groups: [TasksLogic.ReasonGroup]
    let openTrail: () -> Void

    var body: some View {
        if !groups.isEmpty {
            FlowRow(spacing: 6, lineSpacing: 6) {
                Text("Last search passed over:").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.mut)
                ForEach(groups.prefix(5)) { group in
                    HStack(spacing: 5) {
                        Circle().fill(group.bucket.tone.color).frame(width: 6, height: 6)
                        Text("\(group.total) \(group.bucket.label.lowercased())")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.txt.opacity(0.06), in: Capsule())
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(group.qualifier ?? "")
                }
                Button("See the full decision trail", action: openTrail)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .buttonStyle(.plain)
            }
            .padding(.bottom, 10)
        }
    }
}
