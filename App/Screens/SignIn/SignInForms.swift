import SwiftUI
import FusionhaKit

// The sign-in card's steps: server address, the method pill and its
// reveal (password or Plex), and the demo section.

extension SignInView {
    // MARK: Step 1: server

    var serverForm: some View {
        VStack(spacing: 0) {
            LoginField(label: "Server address") {
                TextField("", text: $server, prompt: Text("192.168.1.10:8787 or https://…").foregroundStyle(Theme.dim))
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($field, equals: .server)
                    .onSubmit { Task { await connect() } }
            } focused: { field == .server }
            errorText
            GradientSubmit(title: "Continue", working: working, enabled: !server.isEmpty) {
                Task { await connect() }
            }
        }
    }

    // MARK: Step 2: method pill + reveal

    @ViewBuilder
    func chooser(url: URL, status: SetupStatus) -> some View {
        let methods: [SignInMethod] = (status.offersPassword ? [.fusionha] : []) + (status.offersPlex ? [.plex] : [])
        if methods.isEmpty {
            hint("No sign-in methods are configured — contact your administrator.")
        } else {
            VStack(spacing: 0) {
                if methods.count == 1 {
                    if method == nil {
                        SoloMethodButton(method: methods[0]) { pick(methods[0], url: url) }
                    }
                } else {
                    MethodPill(methods: methods, selection: method) { pick($0, url: url) }
                        .padding(.bottom, method == nil ? 0 : 24)
                }
                Group {
                    switch method {
                    // `.form { animation: fadeUp 0.7s 0.62s }` / `.providers { … 0.74s }`
                    case .fusionha: passwordForm(url: url).loginEntrance(.fadeUp(0.7), delay: 0.62)
                    case .plex: plexReveal(url: url)
                    case nil:
                        if methods.count > 1 { hint("Choose a method above to continue").padding(.top, 34) }
                    }
                }
                .transition(.identity)
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: method)
        }
    }

    func passwordForm(url: URL) -> some View {
        VStack(spacing: 0) {
            LoginField(label: "Username") {
                TextField("", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($field, equals: .username)
                    .onSubmit { field = .password }
            } focused: { field == .username }
            LoginField(label: "Password") {
                SecureField("", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($field, equals: .password)
                    .onSubmit { Task { await passwordSignIn(url: url) } }
            } focused: { field == .password }
            errorText
            GradientSubmit(title: "Sign in", workingTitle: "Signing in…", working: working,
                           enabled: !username.isEmpty && !password.isEmpty) {
                Task { await passwordSignIn(url: url) }
            }
        }
        .onAppear { field = .username }
    }

    @ViewBuilder
    func plexReveal(url: URL) -> some View {
        VStack(spacing: 14) {
            if let pin = plexPin {
                VStack(spacing: 10) {
                    ProgressView().tint(Theme.plexGold).controlSize(.large)
                    Text("Waiting for Plex authorization…")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: 0xC7CBD6))
                    (Text("Or enter code ") + Text(pin.code).font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.txt) + Text(" at plex.tv/link"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 16) {
                        Button("Open Plex") { plexURL = URL(string: pin.authUrl) }
                            .foregroundStyle(Theme.plexGold)
                        Button("Cancel") { cancelPlex() }
                            .foregroundStyle(Theme.mut)
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08)))
                .loginEntrance(.fadeUp(0.3), delay: 0)
            } else {
                Button {
                    Task { await startPlex(url: url) }
                } label: {
                    HStack(spacing: 10) {
                        Image("plex-mark").resizable().scaledToFit().frame(width: 16, height: 16)
                        Text(working ? "Connecting to Plex…" : "Sign in with Plex")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: 0xEDC56E))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.plexGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.plexGold.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .loginEntrance(.fadeUp(0.7), delay: 0.74)
            }
            errorText
        }
    }

    // MARK: Demo

    /// "Explore the demo" (setup-status `demo_mode`): a subtle 44pt button that
    /// enters the read-only demo, or opens the demo credentials form first.
    @ViewBuilder
    func demoSection(url: URL, status: SetupStatus) -> some View {
        if status.demoMode == true {
            let needsCredentials = status.demoRequireCredentials == true
            VStack(spacing: 0) {
                if demoOpen && needsCredentials {
                    LoginField(label: "Demo username") {
                        TextField("", text: $demoUser)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($field, equals: .demoUser)
                            .onSubmit { field = .demoPass }
                    } focused: { field == .demoUser }
                    LoginField(label: "Demo password") {
                        SecureField("", text: $demoPass)
                            .textContentType(.password)
                            .submitLabel(.go)
                            .focused($field, equals: .demoPass)
                            .onSubmit { Task { await enterDemo(url: url, credentials: true) } }
                    } focused: { field == .demoPass }
                    if method == nil { errorText }
                    GradientSubmit(title: "Enter demo", workingTitle: "Entering…", working: working,
                                   enabled: !demoUser.isEmpty && !demoPass.isEmpty) {
                        Task { await enterDemo(url: url, credentials: true) }
                    }
                } else {
                    Button {
                        if needsCredentials {
                            withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.2)) {
                                error = nil
                                demoOpen = true
                            }
                        } else {
                            Task { await enterDemo(url: url, credentials: false) }
                        }
                    } label: {
                        Text(working && method == nil ? "Entering…" : "Explore the demo")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.txt)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.08)))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, demoOpen && needsCredentials ? 0 : 1)
            .transition(.opacity.combined(with: .offset(y: 8)))
            .loginEntrance(.fadeUp(0.7), delay: 0.74)
        }
    }

    func enterDemo(url: URL, credentials: Bool) async {
        working = true
        error = nil
        defer { working = false }
        do {
            try await model.demoSignIn(server: url, username: credentials ? demoUser : nil,
                                       password: credentials ? demoPass : nil)
        } catch APIError.http(401, _) {
            error = "Incorrect demo username or password."
        } catch APIError.http(403, _) {
            error = "The demo isn't available on this server."
        } catch {
            self.error = error.localizedDescription
        }
    }

    @ViewBuilder
    var errorText: some View {
        if let error {
            Text(error)
                .font(.system(size: 13))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
                .padding(.bottom, 14)
        }
    }

    func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.dim)
            .multilineTextAlignment(.center)
    }
}
