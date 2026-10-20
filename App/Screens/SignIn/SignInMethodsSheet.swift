import SwiftUI
import UIKit
import FusionhaKit

// MARK: - Sign-in methods (`UserCredentialsDialog`)

/// "{name} — sign-in methods": every way a person can sign in, each with
/// Set-primary, the admin-only Move, an active switch and Detach; add a
/// password, link Plex. With no `user` it edits the signed-in person (Account,
/// You); Settings › Users passes any account. Every change re-reads the live
/// account afterwards, like the web.
struct SignInMethodsSheet: View {
    var user: UserAccount? = nil
    var onChanged: (() async -> Void)? = nil
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var live: UserAccount?
    @State private var others: [UserAccount] = []
    @State private var busy: Set<Int> = []
    @State private var addingPassword = false
    @State private var password = ""
    @State private var savingPassword = false
    @State private var moving: UserCredential?
    @State private var toast: CalToast?

    private var subject: SignInSubject? {
        if let user { return SignInSubject(live ?? user) }
        return model.me.map { SignInSubject($0) }
    }

    private var isSelf: Bool { subject?.id == model.me?.id }
    private var canAdminSystem: Bool { model.me?.has("system.admin") == true }

    var body: some View {
        NavigationStack {
            if let subject {
                form(subject)
                    .navigationTitle("\(subject.name) — sign-in methods")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } }
                    }
                    .closeOnlyBars()
                    .sheet(item: $moving) { credential in
                        MoveCredentialSheet(subject: subject, credential: credential, candidates: others) { await refresh() }
                    }
            } else {
                ProgressView()
            }
        }
        .calToast($toast)
        .task { if user != nil { await refresh(notify: false) } }
    }

    private func form(_ subject: SignInSubject) -> some View {
        let blocked = subject.addPasswordBlocked(isSelf: isSelf, canAdminSystem: canAdminSystem)
        return Form {
            Section {
                Text("Every way \(subject.name) can sign in. Attaching, detaching or moving one is lossless — role, access and history stay on the identity.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .listRowBackground(Color.clear)
            }

            Section {
                if subject.credentials.isEmpty {
                    Text("No sign-in methods on record yet.").font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
                ForEach(subject.credentials) { credentialRow($0, subject: subject) }
            }
            .listRowBackground(Theme.card)

            Section {
                addRow(subject, blocked: blocked)
            } footer: {
                if !addingPassword {
                    Text(blocked ? "A Plex-linked account needs an admin to add a password. OpenID Connect is coming soon."
                                 : "OpenID Connect is coming soon.")
                }
            }
            .listRowBackground(Theme.card)

            if !subject.hasPlex && !addingPassword {
                Section {
                    SignInPlexLinkCard(subject: subject, toast: $toast) { await refresh() }
                } header: {
                    Text("Plex account")
                } footer: {
                    if !subject.plexLinked {
                        Text("Sign in with Plex to link this account — the password keeps working too.")
                    }
                }
                .listRowBackground(Theme.panel2)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.panel)
        .buttonStyle(.borderless)
    }

    private func credentialRow(_ credential: UserCredential, subject: SignInSubject) -> some View {
        let label = credential.providerLabel
        return SignInCredentialRow(
            credential: credential,
            lastActive: subject.isLastActive(credential),
            working: busy.contains(credential.id),
            canMove: SignInSubject.canMove(credential, canAdminSystem: canAdminSystem),
            onPrimary: { run(credential, failure: "Could not set primary") { client in
                try await client.updateCredential(userId: subject.id, credentialId: credential.id, CredentialPatch(isPrimary: true))
            } },
            onActive: { on in run(credential, failure: on ? "Could not enable" : "Could not disable") { client in
                try await client.updateCredential(userId: subject.id, credentialId: credential.id, CredentialPatch(isActive: on))
            } },
            onMove: { moving = credential },
            onDetach: { run(credential, failure: "Could not detach \(label)") { client in
                try await client.deleteCredential(userId: subject.id, credentialId: credential.id)
            } })
    }

    @ViewBuilder
    private func addRow(_ subject: SignInSubject, blocked: Bool) -> some View {
        if addingPassword {
            SecureField("New password", text: $password)
                .textContentType(.newPassword)
            HStack(spacing: 10) {
                Button("Cancel") { addingPassword = false; password = "" }
                    .buttonStyle(CalButtonStyle(variant: .ghost))
                Button(savingPassword ? "Saving…" : "Save password") { Task { await savePassword(subject) } }
                    .buttonStyle(CalButtonStyle(variant: .primary))
                    .disabled(savingPassword || password.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } else {
            HStack(spacing: 10) {
                if !subject.hasLocal {
                    Button("+ Add password") { addingPassword = true }
                        .buttonStyle(CalButtonStyle(variant: .subtle))
                        .disabled(blocked)
                }
                Button("+ Link OIDC") {}
                    .buttonStyle(CalButtonStyle(variant: .subtle))
                    .disabled(true)
            }
        }
    }

    // MARK: Actions

    private func run(_ credential: UserCredential, failure: String, _ call: @escaping (APIClient) async throws -> Void) {
        guard let client = model.client else { return }
        Task {
            busy.insert(credential.id)
            defer { busy.remove(credential.id) }
            do {
                try await call(client)
            } catch {
                toast = CalToast(title: failure, message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
            }
            await refresh()
        }
    }

    private func savePassword(_ subject: SignInSubject) async {
        guard let client = model.client else { return }
        savingPassword = true
        defer { savingPassword = false }
        do {
            try await client.addPassword(userId: subject.id, password: password)
            password = ""
            addingPassword = false
        } catch {
            toast = CalToast(title: "Could not add a password",
                             message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
        }
        await refresh()
    }

    /// Re-reads the live account (the users list for another person, `/auth/me`
    /// for yourself) and tells the presenter.
    private func refresh(notify: Bool = true) async {
        if let user, let client = model.client, let all = try? await client.userAccounts() {
            live = all.first { $0.id == user.id } ?? live
            others = all.filter { $0.id != user.id }
        }
        if user == nil || isSelf { await model.loadMe() }
        if notify { await onChanged?() }
    }
}
