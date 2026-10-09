import SwiftUI
import FusionhaKit

/// "Edition aliases" (EditionAliasesDialog.tsx): a title's per-item aliases
/// (`GET /api/v1/library/{id}/edition-aliases`), each removable (`DELETE …/{alias_id}`),
/// and the add form (release term → one of the title's non-Standard editions,
/// optional Guarded) posting to the same collection.
struct EditionAliasesSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail

    @State private var aliases: [EditionAlias]?
    @State private var term = ""
    @State private var edition = ""
    @State private var guarded = false
    @State private var error: String?
    @State private var adding = false
    @State private var deleting = false

    /// The alias targets: the title's distinct non-Standard editions.
    private var editionNames: [String] { detail.editionKeysSorted.filter { !$0.isEmpty } }
    private var chosen: String { edition.isEmpty ? (editionNames.first ?? "") : edition }
    private var trimmed: String { term.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canAdd: Bool { !trimmed.isEmpty && !chosen.isEmpty && !adding }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DialogHeading(symbol: "tag", title: "Edition aliases",
                                  subtitle: "Teach \(detail.title) to recognise a title-specific release term as one of its tracked versions.")
                    (Text("Some releases name a cut with a term unique to this title (for example a foreign retitle of a director’s cut). An alias here lets those releases match the right edition — ")
                        + Text("only on this title").bold() + Text(", never any other."))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mut)
                }
                .listRowBackground(Color.clear)
                Section("Aliases") { list }
                    .listRowBackground(Theme.card)
                if editionNames.isEmpty {
                    Section {
                        Text("This title tracks only the Standard edition. Add a version with another edition (e.g. a Director’s Cut) first — an alias can only point at a tracked non-Standard edition.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mut)
                    }
                    .listRowBackground(Theme.card)
                } else {
                    form
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton(title: "Close") { dismiss() } }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .task { await load() }
    }

    @ViewBuilder
    private var list: some View {
        if let aliases {
            if aliases.isEmpty {
                Text("No aliases yet.").foregroundStyle(Theme.mut)
            }
            ForEach(aliases) { alias in
                HStack(spacing: 8) {
                    Text(alias.term).foregroundStyle(Theme.txt)
                    Text("→").foregroundStyle(Theme.dim)
                    Text(alias.edition).foregroundStyle(Theme.edition)
                    if alias.guarded == true {
                        Text("guarded")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.miss)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Theme.miss.opacity(0.5)))
                    }
                    Spacer(minLength: 4)
                    Button { Task { await remove(alias) } } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .tint(Theme.danger)
                        .disabled(deleting)
                        .accessibilityLabel("Remove alias \"\(alias.term)\"")
                }
                .font(.system(size: 14))
            }
        } else {
            Text("Loading aliases…").foregroundStyle(Theme.mut)
        }
    }

    private var form: some View {
        Section {
            TextField("e.g. Vrach Frankenshteyn Cut", text: $term)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Release term")
            Picker("Maps to edition", selection: Binding(get: { chosen }, set: { edition = $0 })) {
                ForEach(editionNames, id: \.self) { Text($0).tag($0) }
            }
            Toggle(isOn: $guarded) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Guarded").bold()
                    Text("For a short or ambiguous term (also a plausible title word). Matches only in a movie release’s trailing edition slot.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                }
            }
            .tint(Theme.indigo)
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.danger)
            }
            Button(adding ? "Adding…" : "Add alias") { Task { await add() } }
                .bold()
                .disabled(!canAdd)
        } header: {
            Text("Release term")
        }
        .listRowBackground(Theme.card)
    }

    private func load() async {
        aliases = (try? await store.client?.editionAliases(itemId: detail.id)) ?? aliases ?? []
    }

    private func add() async {
        guard canAdd, let client = store.client else { return }
        adding = true
        error = nil
        defer { adding = false }
        do {
            try await client.addEditionAlias(itemId: detail.id, EditionAliasCreate(term: trimmed, edition: chosen, guarded: guarded))
            term = ""
            edition = ""
            guarded = false
            await load()
        } catch let failure as APIError {
            error = failure.serverMessage
        } catch {
            self.error = "Could not add alias"
        }
    }

    private func remove(_ alias: EditionAlias) async {
        guard let client = store.client else { return }
        deleting = true
        defer { deleting = false }
        do {
            try await client.deleteEditionAlias(itemId: detail.id, aliasId: alias.id)
            await load()
        } catch {
            store.show("Couldn't remove the alias", variant: .error)
        }
    }
}
