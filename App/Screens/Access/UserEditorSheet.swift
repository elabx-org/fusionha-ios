import SwiftUI
import FusionhaKit

/// One account: rename, role, enable / disable, sign-in methods, request
/// policy, per-instance access (non-admins), sessions, its
/// automatic request sources (Plex watchlist, Letterboxd), delete.
struct UserEditorSheet: View {
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
    @State private var methods = false
    @State private var sessions = false
    @State private var confirmDelete = false
    @State private var password = ""
    @State private var currentPassword = ""

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
                    if isSelf {
                        SecureField("Current password", text: $currentPassword).textContentType(.password)
                    }
                    SecureField("Reset password (optional)", text: $password, prompt: Text("Leave blank to keep current"))
                        .textContentType(.newPassword)
                } header: {
                    Text("Password")
                } footer: {
                    Text(isSelf ? "Enter your current password to set a new one."
                         : "The server checks the person’s current password, so a reset only works if you know it. Otherwise use Sign-in methods.")
                }
                Section {
                    Button("Sign-in methods", systemImage: "lock") { methods = true }
                    Button("Request policy", systemImage: "slider.horizontal.3") { policy = true }
                    if !user.isAdmin {
                        NavigationLink { UserAccessScreen(user: user) } label: {
                            Label("Manage per-instance access…", systemImage: "key")
                        }
                    }
                    Button("Signed-in devices" + ((user.activeSessionCount ?? 0) > 0 ? " · \(user.activeSessionCount ?? 0)" : ""),
                           systemImage: "iphone.and.arrow.forward") { sessions = true }
                }
                UserSourcesSection(user: user)
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
                ToolbarItem(placement: .confirmationAction) { Button("Save", systemImage: "checkmark") { Task { await save() } }.disabled(working) }
            }
            .sheet(isPresented: $methods) {
                SignInMethodsSheet(user: user, onChanged: onChanged).presentationBackground(Theme.panel)
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
        let newPassword = password.trimmingCharacters(in: .whitespaces).isEmpty ? nil : password
        guard !fields.isEmpty || newPassword != nil else { return dismiss() }
        working = true
        defer { working = false }
        do {
            if !fields.isEmpty { _ = try await client.updateUser(id: user.id, fields) }
            if let newPassword {
                try await client.changePassword(userId: user.id, newPassword: newPassword,
                                                currentPassword: isSelf ? currentPassword : "")
            }
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
struct NewUserSheet: View {
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
                    Button("Add", systemImage: "plus") { Task { await create() } }
                        .disabled(working || name.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                }
            }
        }
        .presentationDetents([.mediumFitting, .large])
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
