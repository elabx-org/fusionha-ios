import SwiftUI
import UIKit
import FusionhaKit

// MARK: - Sign-in methods (`UserCredentialsDialog`, isSelf)

struct SignInMethodsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var busy: Set<Int> = []
    @State private var addingPassword = false
    @State private var password = ""
    @State private var savingPassword = false
    @State private var toast: CalToast?

    // Plex link
    @State private var plexStarting = false
    @State private var plexWaiting = false
    @State private var plexURL: URL?
    @State private var plexTask: Task<Void, Never>?
    @State private var unlinking = false

    var body: some View {
        NavigationStack {
            if let me = model.me {
                form(me)
                    .navigationTitle("\(me.displayName) — sign-in methods")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            SheetDoneButton { dismiss() }
                        }
                    }
            } else {
                ProgressView()
            }
        }
        .calToast($toast)
        .sheet(item: $plexURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        .onDisappear { plexTask?.cancel() }
    }

    private func form(_ me: Me) -> some View {
        let credentials = me.credentials ?? []
        let hasLocal = credentials.contains { $0.provider == "local" }
        let hasPlex = credentials.contains { $0.provider == "plex" }
        let activeCount = credentials.filter(\.isActive).count
        let blocked = !hasLocal && hasPlex && !me.has("system.admin")
        return Form {
            Section {
                Text("Every way \(me.displayName) can sign in. Attaching, detaching or moving one is lossless — role, access and history stay on the identity.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .listRowBackground(Color.clear)
            }

            Section {
                if credentials.isEmpty {
                    Text("No sign-in methods on record yet.").font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
                ForEach(credentials) { credential in
                    credentialRow(credential, me: me, lastActive: credential.isActive && activeCount <= 1)
                }
            }
            .listRowBackground(Theme.card)

            Section {
                if addingPassword {
                    SecureField("New password", text: $password)
                        .textContentType(.newPassword)
                    HStack(spacing: 10) {
                        Button("Cancel") { addingPassword = false; password = "" }
                            .buttonStyle(CalButtonStyle(variant: .ghost))
                        Button(savingPassword ? "Saving…" : "Save password") { Task { await savePassword(me) } }
                            .buttonStyle(CalButtonStyle(variant: .primary))
                            .disabled(savingPassword || password.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    HStack(spacing: 10) {
                        if !hasLocal {
                            Button("+ Add password") { addingPassword = true }
                                .buttonStyle(CalButtonStyle(variant: .subtle))
                                .disabled(blocked)
                        }
                        Button("+ Link OIDC") {}
                            .buttonStyle(CalButtonStyle(variant: .subtle))
                            .disabled(true)
                    }
                }
            } footer: {
                if !addingPassword {
                    Text(blocked ? "A Plex-linked account needs an admin to add a password. OpenID Connect is coming soon."
                                 : "OpenID Connect is coming soon.")
                }
            }
            .listRowBackground(Theme.card)

            if !hasPlex {
                Section {
                    plexCard(me)
                } header: {
                    Text("Plex account")
                } footer: {
                    if me.plexLinked != true {
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

    private func credentialRow(_ credential: UserCredential, me: Me, lastActive: Bool) -> some View {
        let working = busy.contains(credential.id)
        return HStack(spacing: 12) {
            providerTile(credential.provider, size: 32, radius: 9)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(credential.providerLabel).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    if credential.isPrimary {
                        Text("primary")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.done)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .background(Theme.done.opacity(0.15), in: Capsule())
                    }
                }
                Text("\(credential.provider) · \(credential.externalId ?? credential.displayHandle ?? "")")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !credential.isPrimary {
                Button {
                    Task { await patch(credential, me: me, CredentialPatch(isPrimary: true), failure: "Could not set primary") }
                } label: {
                    Image(systemName: "star").font(.system(size: 14))
                }
                .foregroundStyle(Theme.mut)
                .disabled(working)
                .accessibilityLabel("Set \(credential.providerLabel) as primary")
            }
            Toggle("Active", isOn: Binding(
                get: { credential.isActive },
                set: { on in
                    Task {
                        await patch(credential, me: me, CredentialPatch(isActive: on),
                                    failure: on ? "Could not enable" : "Could not disable")
                    }
                }))
                .labelsHidden()
                .tint(Theme.done)
                .disabled(working || (lastActive && credential.isActive))
            Button {
                Task { await detach(credential, me: me) }
            } label: {
                Image(systemName: "trash").font(.system(size: 14))
            }
            .foregroundStyle(Theme.danger)
            .disabled(working || lastActive)
            .accessibilityLabel("Detach \(credential.providerLabel)")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func providerTile(_ provider: String, size: CGFloat, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch provider {
        case "plex":
            Image("plex-mark").renderingMode(.template).resizable().scaledToFit()
                .frame(width: size * 0.5, height: size * 0.5)
                .foregroundStyle(Theme.plexGold)
                .frame(width: size, height: size)
                .background(Theme.plexGold.opacity(size > 40 ? 0.18 : 0.15), in: shape)
        case "local":
            Image(systemName: "key").font(.system(size: size * 0.42))
                .foregroundStyle(Theme.mut)
                .frame(width: size, height: size)
                .background(Theme.panel2, in: shape)
        default:
            Image(systemName: "globe").font(.system(size: size * 0.42))
                .foregroundStyle(Theme.done)
                .frame(width: size, height: size)
                .background(Theme.done.opacity(0.15), in: shape)
        }
    }

    @ViewBuilder
    private func plexCard(_ me: Me) -> some View {
        HStack(spacing: 12) {
            providerTile("plex", size: 46, radius: 12)
            VStack(alignment: .leading, spacing: 3) {
                if me.plexLinked == true {
                    HStack(spacing: 6) {
                        Text(me.plexUsername ?? "Plex").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        Text("Linked")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.done)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .background(Theme.done.opacity(0.15), in: Capsule())
                    }
                    Text("Can sign in with Plex; password still works.").font(.system(size: 12)).foregroundStyle(Theme.mut)
                } else if plexWaiting {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Waiting for Plex authorization…").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    }
                } else {
                    Text("Not linked").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text("No Plex account is linked to this fusionha account.").font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        if me.plexLinked == true {
            Button(unlinking ? "Unlinking…" : "Unlink") { Task { await unlink(me) } }
                .buttonStyle(CalButtonStyle(variant: .danger))
                .disabled(unlinking)
        } else if plexWaiting {
            Button("Cancel") { cancelPlex() }
                .buttonStyle(CalButtonStyle(variant: .ghost))
        } else {
            Button(plexStarting ? "Starting…" : "Link Plex account") { startPlex(me) }
                .buttonStyle(CalButtonStyle(variant: .subtle))
                .disabled(plexStarting)
        }
    }

    // MARK: Actions (each re-fetches /auth/me afterwards, like the web)

    private func patch(_ credential: UserCredential, me: Me, _ body: CredentialPatch, failure: String) async {
        guard let client = model.client else { return }
        busy.insert(credential.id)
        defer { busy.remove(credential.id) }
        do {
            try await client.updateCredential(userId: me.id, credentialId: credential.id, body)
        } catch {
            toast = CalToast(title: failure, message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
        }
        await model.loadMe()
    }

    private func detach(_ credential: UserCredential, me: Me) async {
        guard let client = model.client else { return }
        busy.insert(credential.id)
        defer { busy.remove(credential.id) }
        do {
            try await client.deleteCredential(userId: me.id, credentialId: credential.id)
        } catch {
            toast = CalToast(title: "Could not detach \(credential.providerLabel)",
                             message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
        }
        await model.loadMe()
    }

    private func savePassword(_ me: Me) async {
        guard let client = model.client else { return }
        savingPassword = true
        defer { savingPassword = false }
        do {
            try await client.addPassword(userId: me.id, password: password)
            password = ""
            addingPassword = false
        } catch {
            toast = CalToast(title: "Could not add a password",
                             message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
        }
        await model.loadMe()
    }

    private func unlink(_ me: Me) async {
        guard let client = model.client else { return }
        unlinking = true
        defer { unlinking = false }
        do {
            try await client.unlinkPlex(userId: me.id)
        } catch {
            toast = CalToast(title: "Could not unlink Plex",
                             message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
        }
        await model.loadMe()
    }

    /// `POST …/plex/link`, open Plex, then poll `…/check` every 2s for up to 10 minutes.
    private func startPlex(_ me: Me) {
        guard let client = model.client else { return }
        plexStarting = true
        plexTask?.cancel()
        plexTask = Task {
            do {
                let pin = try await client.startPlexLink(userId: me.id)
                plexStarting = false
                plexWaiting = true
                plexURL = URL(string: pin.authUrl)
                let deadline = Date().addingTimeInterval(600)
                while !Task.isCancelled {
                    if Date() > deadline {
                        finishPlex()
                        toast = CalToast(title: "Plex link timed out",
                                         message: "The authorization window expired. Please try again.", isError: true)
                        return
                    }
                    try await Task.sleep(for: .seconds(2))
                    if case .linked(let updated) = try await client.checkPlexLink(userId: me.id, pinId: pin.id) {
                        finishPlex()
                        toast = CalToast(title: "Plex account linked",
                                         message: "Signed in with Plex as \(updated.plexUsername ?? "Plex") — the password still works.")
                        await model.loadMe()
                        return
                    }
                }
            } catch is CancellationError {
            } catch APIError.http(409, _) {
                finishPlex()
                toast = CalToast(title: "Already linked",
                                 message: "That Plex account is already linked to another user.", isError: true)
            } catch {
                finishPlex()
                toast = CalToast(title: "Could not link Plex",
                                 message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
            }
        }
    }

    private func finishPlex() {
        plexStarting = false
        plexWaiting = false
        plexURL = nil
    }

    private func cancelPlex() {
        plexTask?.cancel()
        plexTask = nil
        finishPlex()
    }
}
