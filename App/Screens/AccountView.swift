import SwiftUI
import UIKit
import WidgetKit
import FusionhaKit

/// The web's Account page (`routes/Account.tsx`, "You"): a centred role-tinted
/// avatar, the name and role badge, then Requests made · Sign-in methods ·
/// Reset cache & reload · Sign out. No page title, like the web.
struct AccountView: View {
    @Environment(AppModel.self) private var model
    @State private var requestCount: Int?
    @State private var showingMethods = false
    @State private var resetting = false
    @State private var signingOut = false
    @State private var toast: CalToast?

    var body: some View {
        ScrollView {
            Group {
                if let me = model.me {
                    content(me)
                } else {
                    CalEmptyState(message: "Loading account…")
                }
            }
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .calToast($toast)
        .task { await loadRequests() }
        .sheet(isPresented: $showingMethods) {
            SignInMethodsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ACCOUNT"] == "methods" {
                try? await Task.sleep(for: .seconds(1.5))
                showingMethods = true
            }
            #endif
        }
    }

    private func content(_ me: Me) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                AccountAvatar(me: me, size: 74)
                Text(me.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.18)
                    .foregroundStyle(Theme.txt)
                    .padding(.top, 4)
                RoleBadge(me: me)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 26)
            .calReveal(0, stagger: 0.06)

            row {
                Text("Requests made").foregroundStyle(Theme.txt)
                Spacer()
                Text("\(requestCount ?? 0)").fontWeight(.semibold).foregroundStyle(Theme.dim)
            }
            .calReveal(1, stagger: 0.06)

            rowButton("Sign-in methods") { showingMethods = true }
                .calReveal(2, stagger: 0.06)

            rowButton(resetting ? "Resetting…" : "Reset cache & reload") { Task { await resetCache() } }
                .disabled(resetting)
                .calReveal(3, stagger: 0.06)

            row {
                Button("Sign out") {
                    signingOut = true
                    Task { await model.signOutRevokingToken() }
                }
                .buttonStyle(CalButtonStyle(variant: .danger, fullWidth: true))
                .disabled(signingOut)
            }
            .calReveal(4, stagger: 0.06)
        }
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) { content() }
            .font(.system(size: 13.5))
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, minHeight: 0, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
            .padding(.top, 10)
    }

    private func rowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 13)
                .padding(.horizontal, 15)
                .contentShape(Rectangle())
        }
        .buttonStyle(AccountRowButtonStyle())
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
        .padding(.top, 10)
    }

    private func loadRequests() async {
        guard let client = model.client else { return }
        if let list = try? await client.requests() { requestCount = list.count }
    }

    /// The iOS form of the web's `resetAppCache`: drop cached responses and artwork
    /// and reload what's on screen. The sign-in and preferences stay.
    private func resetCache() async {
        resetting = true
        URLCache.shared.removeAllCachedResponses()
        await model.loadMe()
        if !model.requestScoped {
            await model.loadLibrary()
            await model.refreshQueue()
        }
        await loadRequests()
        WidgetCenter.shared.reloadAllTimelines()
        resetting = false
        toast = CalToast(message: "Cache cleared and reloaded.")
    }
}

/// The Account sheet the avatar menu opens on the shell (RootView hook).
struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AccountView()
                .background(Theme.bg.ignoresSafeArea())
                .navigationTitle("Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

private struct AccountRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.cyan : Theme.txt)
    }
}

// MARK: Avatar + role badge (`access-shared.tsx`)

struct AccountAvatar: View {
    @Environment(AppModel.self) private var model
    let me: Me
    var size: CGFloat = 74
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(me.displayInitials)
                    .font(.system(size: size * 24 / 74, weight: .bold))
                    .foregroundStyle(me.roleTone == .other ? Theme.mut : Theme.txt)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.55), radius: 14, y: 10)
        .accessibilityHidden(true)
        .task(id: me.thumb) {
            // The same-origin avatar proxy; initials when it fails.
            guard me.thumb != nil, let client = model.client,
                  let data = try? await client.avatar(userId: me.id) else { image = nil; return }
            image = UIImage(data: data)
        }
    }

    private var fill: AnyShapeStyle {
        switch me.roleTone {
        case .admin:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x494BAE), Theme.indigo],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .manager:
            return AnyShapeStyle(LinearGradient(colors: [Theme.cyan, Color(hex: 0x18949F)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .requestor:
            return AnyShapeStyle(LinearGradient(colors: [Theme.miss, Color(hex: 0xAC6F08)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .other:
            return AnyShapeStyle(Theme.panel2)
        }
    }
}

struct RoleBadge: View {
    let me: Me

    private var tint: Color {
        switch me.roleTone {
        case .admin: return Theme.indigo
        case .manager: return Theme.cyan
        case .requestor: return Theme.miss
        case .other: return Theme.mut
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(me.accountRoleName ?? "No role")
        }
        .font(.system(size: 10.5, weight: .bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(me.roleTone == .other ? Theme.panel2 : tint.opacity(me.roleTone == .manager ? 0.15 : 0.16),
                    in: Capsule())
    }
}

// MARK: Sign out

extension AppModel {
    /// Sign out like the web, and also revoke this device's personal token
    /// (`DELETE /api/v1/tokens/{tokenId}`) so it stops working server-side.
    func signOutRevokingToken() async {
        if let creds = credentials {
            let client = creds.client()
            if creds.method == .session || client.sessionTokenFromCookie() != nil {
                try? await client.logout()
            }
            if let id = creds.tokenId {
                try? await client.revokeToken(id: id)
            }
        }
        signOut()
    }
}

// MARK: - Sign-in methods (`UserCredentialsDialog`, isSelf)

private struct SignInMethodsSheet: View {
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
                            Button("Done") { dismiss() }
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
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
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
