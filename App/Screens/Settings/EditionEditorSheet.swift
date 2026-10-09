import SwiftUI
import FusionhaKit

struct EditionDraft: Identifiable {
    let id = UUID()
    let editionId: Int?
    var name: String
    var aliases: [String]

    init(_ def: JSONRecord?) {
        editionId = def?.id
        name = def?["name"]?.string ?? ""
        aliases = (def?["aliases"]?.array ?? []).compactMap(\.string)
    }
}

/// Add / edit an edition: name plus alias chips (Return adds one).
struct EditionEditor: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var draft: EditionDraft
    let onSaved: () async -> Void
    @State private var aliasInput = ""
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("", text: $draft.name, prompt: Text("e.g. Open Matte").foregroundStyle(Theme.dim))
                        .onSubmit { Task { await save() } }
                }
                .listRowBackground(Theme.card)
                Section {
                    if draft.aliases.isEmpty {
                        Text("No extra aliases — the name is always matched")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim)
                    }
                    ForEach(draft.aliases, id: \.self) { alias in
                        HStack {
                            Text(alias).font(.system(size: 13))
                            Spacer()
                            Button { draft.aliases.removeAll { $0 == alias } } label: {
                                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.mut)
                            .accessibilityLabel("Remove alias \(alias)")
                        }
                    }
                    TextField("", text: $aliasInput, prompt: Text("Add a spelling and press Return").foregroundStyle(Theme.dim))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit(addAlias)
                        .accessibilityLabel("Add alias")
                } header: {
                    Text("Aliases")
                }
                .listRowBackground(Theme.card)
                if let error {
                    Text(error).font(.system(size: 12.5)).foregroundStyle(Theme.danger)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
            .navigationTitle(draft.editionId == nil ? "Add edition" : "Edit edition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetDoneButton(title: "Save") { Task { await save() } }
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
    }

    private func addAlias() {
        let value = aliasInput.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        if !draft.aliases.contains(where: { $0.lowercased() == value.lowercased() }) {
            draft.aliases.append(value)
        }
        aliasInput = ""
    }

    private func save() async {
        addAlias()
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let client = store.client else { return }
        saving = true
        defer { saving = false }
        error = nil
        let body: JSONValue = .object(["name": .string(name), "aliases": .array(draft.aliases.map(JSONValue.string))])
        do {
            if let id = draft.editionId {
                try await client.json("PATCH", "/api/v1/config/editions/\(id)", body: body)
            } else {
                try await client.json("POST", "/api/v1/config/editions", body: body)
            }
            await onSaved()
            dismiss()
        } catch APIError.http(409, _) {
            error = "An edition with that name already exists."
        } catch {
            self.error = "Could not save the edition. Please try again."
        }
    }
}
