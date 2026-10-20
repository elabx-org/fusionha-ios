import SwiftUI
import FusionhaKit

/// The quality-profile editor (web `ProfileEditor`), new when `profile` is nil:
/// name and kind, the live Qualities / Scored formats / Cutoff summary, the
/// upgrade rules, and links to the Qualities ladder and Custom Formats scores.
/// Saves the same arr-shaped body as the web (`QualityProfileBody`).
struct QualityProfileEditorSheet: View {
    let onChanged: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: QualityProfileDraft
    @State private var saving = false
    @State private var confirmDelete = false
    @State private var error: String?
    /// The sheet's own width (`wide`).
    @State private var width: CGFloat = 0
    @State private var groupEdit = false

    init(profile: QualityProfileRecord?, onChanged: @escaping () async -> Void) {
        self.onChanged = onChanged
        _draft = State(initialValue: QualityProfileDraft(profile))
    }

    var body: some View {
        NavigationStack {
            Group {
                if wide {
                    // Web `.body` above 820 (`minmax(340px, 0.9fr) 1.3fr`):
                    // the profile and its Qualities | Custom Formats.
                    HStack(spacing: 0) {
                        Form {
                            fields
                            QualityProfileLadderSection(draft: draft, groupEdit: groupEdit) { groupEdit.toggle() }
                            footer
                        }
                        .frame(width: max(340, (width - 1) * 0.9 / 2.2))
                        Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea(edges: .bottom)
                        QualityProfileFormatScoresPage(draft: draft)
                    }
                } else {
                    Form {
                        fields
                        Section {
                            NavigationLink {
                                QualityProfileLadderPage(draft: draft)
                            } label: {
                                LabeledContent("Qualities", value: "\(draft.allowedCount) allowed · \(draft.cutoffLabel)")
                            }
                            NavigationLink {
                                QualityProfileFormatScoresPage(draft: draft)
                                    .navigationTitle("Custom Formats")
                                    .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                LabeledContent("Custom Formats", value: "\(draft.scoredCount) scored")
                            }
                        }
                        footer
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .navigationTitle("Quality Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save profile", systemImage: "checkmark") { Task { await save() } }
                        .disabled(!draft.valid || saving)
                }
            }
            .confirmationDialog("Delete \(draft.original?.name ?? "this profile")?",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Task { await delete() } }
            }
            .task { await loadFormats() }
        }
    }

    /// Above 820 of the sheet's own width (ruling S5: reached only by a wide
    /// page sheet, never in iPhone Duo's sheet).
    private var wide: Bool { width > 820 }

    @ViewBuilder private var fields: some View {
        identity
        summary
        QualityProfileRulesSection(draft: draft)
    }

    @ViewBuilder private var footer: some View {
        if draft.original != nil {
            Section {
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            }
        }
        if let error { Section { Text(error).foregroundStyle(Theme.danger).font(.footnote) } }
    }

    private var identity: some View {
        Section {
            TextField("Profile name", text: $draft.fields.name)
                .autocorrectionDisabled()
            if draft.original == nil {
                Picker("Kind", selection: kindBinding) {
                    ForEach(QualityProfileKinds.all, id: \.self) { Text(QualityProfileKinds.label($0)).tag($0) }
                }
            } else {
                LabeledContent("Kind", value: draft.fields.mediaKind == nil ? "legacy: no kind"
                                                                            : QualityProfileKinds.label(draft.fields.mediaKind))
            }
        } footer: {
            if draft.original != nil && draft.fields.mediaKind == nil {
                Text("Created before kind scoping — usable for movies, series and anime; sees every custom format.")
            }
        }
    }

    private var kindBinding: Binding<String> {
        Binding(get: { draft.fields.mediaKind ?? "movie" }, set: { draft.fields.mediaKind = $0 })
    }

    private var summary: some View {
        Section {
            HStack(spacing: 14) {
                stat("Qualities", "\(draft.allowedCount)", Theme.txt)
                stat("Scored formats", "\(draft.scoredCount)", Theme.txt)
                stat("Cutoff", draft.cutoffLabel, Theme.done)
            }
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(Theme.mut)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadFormats() async {
        guard let client = model.client, draft.formats.isEmpty else { return }
        draft.formats = (try? await client.qualityProfileFormatOptions()) ?? []
    }

    private func save() async {
        guard let client = model.client, draft.valid else { return }
        saving = true
        defer { saving = false }
        do {
            if let original = draft.original {
                try await client.updateQualityProfile(id: original.id, draft.body())
            } else {
                try await client.createQualityProfile(draft.body())
            }
            await onChanged()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t save the profile.")
        }
    }

    private func delete() async {
        guard let client = model.client, let id = draft.original?.id else { return }
        do {
            try await client.deleteQualityProfile(id: id)
            await onChanged()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t delete the profile. It may still be in use.")
        }
    }
}
