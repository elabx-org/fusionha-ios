import SwiftUI
import FusionhaKit

/// Settings › Access › Roles (web `RolesPanel`): built-in and custom roles,
/// each with its admin permissions and what it can do on every instance; add,
/// edit or delete a custom role, and open any role's request policy. The keys
/// offered come from `GET /roles/catalog`, never a fixed list.
struct RolesSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var roles: [RoleDetail]?
    @State private var catalog: RoleCatalog?
    @State private var error: String?
    @State private var editing: RoleEditTarget?

    var body: some View {
        SettingsForm(slug: "roles") {
            Section {
                Button("Add role", systemImage: "plus") { editing = .new }
            }
            if let error {
                SettingsLoadingRow(error: error)
            } else if let roles {
                Section("Roles") {
                    ForEach(roles) { r in
                        Button { editing = .edit(r) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(r.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                                        if r.isBuiltin {
                                            Text("Built-in")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Theme.mut)
                                                .padding(.horizontal, 7).padding(.vertical, 2)
                                                .background(Theme.panel2, in: Capsule())
                                        }
                                    }
                                    Text(r.permissions.isEmpty ? "No admin permissions"
                                         : r.permissions.map { AccessLabels.label($0, AccessLabels.permissions) }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(Theme.mut).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.dim)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                SettingsLoadingRow()
            }
        }
        .task { await load() }
        .sheet(item: $editing) { t in RoleEditorSheet(target: t, catalog: catalog) { await load() } }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            roles = try await client.roleDetails()
            catalog = (try? await client.roleCatalog()) ?? catalog
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the roles. Managing roles needs Manage roles.")
        }
    }
}

enum RoleEditTarget: Identifiable {
    case new
    case edit(RoleDetail)
    var id: Int { if case .edit(let r) = self { return r.id }; return -1 }
}

private struct RoleEditorSheet: View {
    let target: RoleEditTarget
    let catalog: RoleCatalog?
    let onChanged: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var about: String
    @State private var permissions: Set<String>
    @State private var capabilities: Set<String>
    @State private var working = false
    @State private var error: String?
    @State private var policy = false
    @State private var confirmDelete = false

    init(target: RoleEditTarget, catalog: RoleCatalog?, onChanged: @escaping () async -> Void) {
        self.target = target
        self.catalog = catalog
        self.onChanged = onChanged
        let role: RoleDetail? = { if case .edit(let r) = target { return r }; return nil }()
        _name = State(initialValue: role?.name ?? "")
        _about = State(initialValue: role?.description ?? "")
        _permissions = State(initialValue: Set(role?.permissions ?? []))
        _capabilities = State(initialValue: Set(role?.defaultCapabilities ?? ["view", "request"]))
    }

    private var role: RoleDetail? { if case .edit(let r) = target { return r }; return nil }
    private var builtIn: Bool { role?.isBuiltin == true }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Description", text: $about, axis: .vertical).lineLimit(1...3)
                }
                .disabled(builtIn)
                Section("What they can do") {
                    ForEach(catalog?.capabilities ?? Array(AccessLabels.capabilities.keys).sorted(), id: \.self) { key in
                        toggle(AccessLabels.label(key, AccessLabels.capabilities), key, in: $capabilities)
                    }
                }
                .disabled(builtIn)
                Section("Admin permissions") {
                    ForEach(catalog?.permissions ?? Array(AccessLabels.permissions.keys).sorted(), id: \.self) { key in
                        toggle(AccessLabels.label(key, AccessLabels.permissions), key, in: $permissions)
                    }
                }
                .disabled(builtIn)
                if let role {
                    Section {
                        Button("Request policy", systemImage: "slider.horizontal.3") { policy = true }
                        if !builtIn { Button("Delete role", systemImage: "trash", role: .destructive) { confirmDelete = true } }
                    } footer: {
                        if builtIn { Text("A built-in role can’t be renamed, changed or deleted; its request policy can.") }
                    }
                    .sheet(isPresented: $policy) { RequestPolicySheet(target: .role(role.id, role.name)) }
                }
                if let error { Section { Text(error).foregroundStyle(Theme.danger).font(.footnote) } }
            }
            .navigationTitle(role?.name ?? "Add role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                if !builtIn {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark") { Task { await save() } }
                            .disabled(working || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .confirmationDialog("Delete \(role?.name ?? "this role")?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete role", role: .destructive) { Task { await delete() } }
            }
        }
    }

    private func toggle(_ label: String, _ key: String, in set: Binding<Set<String>>) -> some View {
        Toggle(label, isOn: Binding(get: { set.wrappedValue.contains(key) },
                                    set: { on in if on { set.wrappedValue.insert(key) } else { set.wrappedValue.remove(key) } }))
            .tint(Theme.i1)
    }

    private func save() async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            let text = about.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await client.saveRole(id: role?.id, name: name.trimmingCharacters(in: .whitespaces),
                                          description: text.isEmpty ? nil : text,
                                          permissions: permissions.sorted(), capabilities: capabilities.sorted())
            await onChanged()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t save the role.")
        }
    }

    private func delete() async {
        guard let client = model.client, let id = role?.id else { return }
        do {
            try await client.deleteRole(id: id)
            await onChanged()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t delete the role. Move its members to another role first.")
        }
    }
}
