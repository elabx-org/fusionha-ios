import SwiftUI
import FusionhaKit

/// Settings › Access › Users (web `UsersPanel`): every account with its role,
/// sign-in source, live sessions and whether it is disabled; add an account;
/// tap one to rename, change its role, disable it, sign it out, open its
/// request policy or delete it. Needs Manage users.
struct UsersSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var users: [UserAccount]?
    @State private var roles: [RoleDetail] = []
    @State private var error: String?
    @State private var editing: UserAccount?
    @State private var adding = false

    var body: some View {
        SettingsForm(slug: "access") {
            Section {
                Button("Add user", systemImage: "person.badge.plus") { adding = true }
            }
            if let error {
                SettingsLoadingRow(error: error)
            } else if let users {
                Section("\(users.count) \(users.count == 1 ? "account" : "accounts")") {
                    ForEach(users) { u in
                        Button { editing = u } label: { row(u) }.buttonStyle(.plain)
                    }
                }
            } else {
                SettingsLoadingRow()
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { u in UserEditorSheet(user: u, roles: roles) { await load() } }
        .sheet(isPresented: $adding) { NewUserSheet(roles: roles) { await load() } }
    }

    private func row(_ u: UserAccount) -> some View {
        HStack(spacing: 12) {
            Image(systemName: u.isAdmin ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                .font(.system(size: 22)).foregroundStyle(u.isActive == false ? Theme.dim : Theme.i2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(u.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                    if u.authProvider == "plex" { Text("Plex").font(.caption2.weight(.bold)).foregroundStyle(Theme.miss) }
                    if u.isActive == false { Text("Disabled").font(.caption2.weight(.bold)).foregroundStyle(Theme.danger) }
                }
                Text([u.isAdmin ? "Admin" : (u.roleName ?? "No role"),
                      (u.activeSessionCount ?? 0) > 0 ? "\(u.activeSessionCount ?? 0) active \((u.activeSessionCount ?? 0) == 1 ? "session" : "sessions")" : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.dim)
        }
        .contentShape(Rectangle())
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            users = try await client.userAccounts()
            roles = (try? await client.roleDetails()) ?? roles
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the users. Managing users needs Manage users.")
        }
    }
}

/// One account: rename, role, enable / disable, sessions, request policy, delete.
private struct UserEditorSheet: View {
    let user: UserAccount
    let roles: [RoleDetail]
    let onChanged: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var roleId: Int?
    @State private var active: Bool
    @State private var working = false
    @State private var error: String?
    @State private var policy = false
    @State private var sessions = false
    @State private var confirmDelete = false

    init(user: UserAccount, roles: [RoleDetail], onChanged: @escaping () async -> Void) {
        self.user = user
        self.roles = roles
        self.onChanged = onChanged
        _name = State(initialValue: user.username)
        _roleId = State(initialValue: user.roleId)
        _active = State(initialValue: user.isActive != false)
    }

    private var isSelf: Bool { user.id == model.me?.id }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $name).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("Role", selection: $roleId) {
                        Text("No role").tag(Int?.none)
                        ForEach(roles) { Text($0.name).tag(Int?.some($0.id)) }
                    }
                    Toggle("Can sign in", isOn: $active).tint(Theme.i1).disabled(isSelf)
                } footer: {
                    Text(isSelf ? "You can’t disable your own account." : "Disabling blocks sign-in, signs out every session and stops the account’s API tokens. It can be turned back on.")
                }
                Section {
                    Button("Request policy", systemImage: "slider.horizontal.3") { policy = true }
                    Button("Signed-in devices" + ((user.activeSessionCount ?? 0) > 0 ? " · \(user.activeSessionCount ?? 0)" : ""),
                           systemImage: "iphone.and.arrow.forward") { sessions = true }
                }
                if !isSelf {
                    Section {
                        Button("Delete user", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(Theme.danger).font(.footnote) } }
            }
            .disabled(working)
            .navigationTitle(user.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(working ? "Saving…" : "Save") { Task { await save() } } }
            }
            .sheet(isPresented: $policy) { RequestPolicySheet(target: .user(user.id, user.displayName)) }
            .sheet(isPresented: $sessions) { AccountSessionsSheet(userId: user.id, title: "\(user.displayName)’s devices") }
            .confirmationDialog("Delete \(user.displayName)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete user", role: .destructive) { Task { await delete() } }
            } message: {
                Text("Their requests and reports stay; the account and its tokens are removed.")
            }
        }
    }

    private func save() async {
        guard let client = model.client else { return }
        var fields: [String: SettingsJSON] = [:]
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed != user.username, !trimmed.isEmpty { fields["username"] = .string(trimmed) }
        if roleId != user.roleId { fields["role_id"] = roleId.map { .int($0) } ?? .null }
        if active != (user.isActive != false) { fields["is_active"] = .bool(active) }
        guard !fields.isEmpty else { return dismiss() }
        working = true
        defer { working = false }
        do {
            _ = try await client.updateUser(id: user.id, fields)
            await onChanged()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t save the user.")
        }
    }

    private func delete() async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            try await client.deleteUser(id: user.id)
            await onChanged()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t delete the user.")
        }
    }
}

/// A new local account: username, password and role.
private struct NewUserSheet: View {
    let roles: [RoleDetail]
    let onCreated: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var password = ""
    @State private var roleId: Int?
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Username", text: $name).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Password", text: $password)
                Picker("Role", selection: $roleId) {
                    Text("No role").tag(Int?.none)
                    ForEach(roles) { Text($0.name).tag(Int?.some($0.id)) }
                }
                if let error { Text(error).foregroundStyle(Theme.danger).font(.footnote) }
            }
            .navigationTitle("Add user")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(working ? "Adding…" : "Add") { Task { await create() } }
                        .disabled(working || name.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func create() async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            _ = try await client.createUser(username: name.trimmingCharacters(in: .whitespaces), password: password, roleId: roleId)
            await onCreated()
            dismiss()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t add the user.")
        }
    }
}
