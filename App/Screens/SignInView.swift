import SwiftUI
import FusionhaKit

enum SignInMethod: Hashable {
    case fusionha, plex
}

/// The web login page (routes/Login.tsx) rebuilt natively: the animated
/// backdrop the admin picked, the glass card with the fusionha logo,
/// "Welcome back", the method pill (fusionha / Plex) and the reveal below it.
/// The app first asks for the server address, in the same card.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("lastServer") private var server = ""
    @State private var connected: (url: URL, status: SetupStatus)?
    @State private var method: SignInMethod?
    @State private var username = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?
    @State private var plexURL: URL?
    @State private var plexPin: PlexPin?
    @State private var plexTask: Task<Void, Never>?
    @State private var demoOpen = false
    @State private var demoUser = ""
    @State private var demoPass = ""
    @FocusState private var field: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Field { case server, username, password, demoUser, demoPass }

    private var status: SetupStatus? { connected?.status }

    /// Reduce Motion, or the server's `animations_enabled` when the app still
    /// knows it (setup-status doesn't carry it, so a fresh sign-in animates).
    private var motionOff: Bool { reduceMotion || !model.animationsEnabled }

    /// `login_background` (unknown → aurora, like `resolveBackground`).
    private var backdropMode: BackdropMode {
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_LOGIN_BACKGROUND"], !forced.isEmpty {
            return BackdropMode(resolving: forced)
        }
        #endif
        return BackdropMode(resolving: status?.loginBackground)
    }

    /// `login_layout`: "split" puts the backdrop in a hero above a solid form
    /// panel (the web's ≤760px split); anything else is the centered card.
    private var isSplit: Bool {
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_LOGIN_LAYOUT"], !forced.isEmpty {
            return forced == "split"
        }
        #endif
        return status?.loginLayout == "split"
    }

    var body: some View {
        ZStack {
            CSSRadialGradient.stage.ignoresSafeArea()
            if isSplit {
                splitStage
            } else {
                centeredStage
            }
        }
        .overlay(alignment: .bottom) {
            ToastHost().padding(.bottom, 24)
        }
        .environment(\.motionEnabled, !motionOff)
        .preferredColorScheme(.dark)
        .sheet(item: $plexURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        #if DEBUG
        .task {
            // CI screenshots: connect to the mock server and pick a method.
            let env = ProcessInfo.processInfo.environment
            guard let login = env["FUSIONHA_SCREENSHOT_LOGIN"], !login.isEmpty else { return }
            server = login
            await connect()
            if env["FUSIONHA_SCREENSHOT_METHOD"] == "fusionha" { method = .fusionha }
            if env["FUSIONHA_SCREENSHOT_METHOD"] == "demo" { demoOpen = true }
        }
        #endif
    }

    // MARK: Layouts

    /// `[data-layout='centered']`: full-bleed backdrop + veil, the glass card
    /// centred in a 384pt column.
    private var centeredStage: some View {
        ZStack {
            LoginBackdrop(mode: backdropMode, motionOff: motionOff)
                .ignoresSafeArea()
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 18) {
                        card
                        changeServer
                    }
                    .frame(maxWidth: 384)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    /// `[data-layout='split']` at phone width (`@media (max-width: 760px)`):
    /// one column, the animated hero (min 190pt) over the solid form panel;
    /// spare height is shared between the two rows like the CSS grid.
    private var splitStage: some View {
        GeometryReader { geo in
            ScrollView {
                StretchRows(minHeight: geo.size.height) {
                    ZStack {
                        Color(hex: 0x0B0D13)
                        LoginBackdrop(mode: backdropMode, motionOff: motionOff)
                        brand(hero: true)
                            .padding(40)
                            .loginEntrance(.riseIn(1.0), delay: 0.1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 190)
                    .clipped()

                    VStack(spacing: 18) {
                        VStack(spacing: 0) {
                            header(centered: false)
                            content
                        }
                        .disabled(working)
                        changeServer
                    }
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LinearGradient(colors: [Color(red: 19 / 255, green: 21 / 255, blue: 28 / 255).opacity(0.98),
                                                        Color(red: 12 / 255, green: 13 / 255, blue: 18 / 255).opacity(0.99)],
                                               startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea(.container)
    }

    @ViewBuilder
    private var changeServer: some View {
        if let connected {
            Button {
                withAnimation(.snappy) { reset() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                    Text(connected.url.host() ?? connected.url.absoluteString)
                    Text("·")
                    Text("Change").foregroundStyle(Theme.cyan)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.mut)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Card

    private var card: some View {
        VStack(spacing: 0) {
            brand(hero: false)
            header(centered: true)
            content
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(red: 20 / 255, green: 22 / 255, blue: 31 / 255).opacity(0.9),
                                    Color(red: 12 / 255, green: 13 / 255, blue: 19 / 255).opacity(0.95)],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(Material.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.1)))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .center))
        }
        .shadow(color: .black.opacity(0.95), radius: 55, y: 40)
        // `.card { animation: riseIn 0.9s }`
        .loginEntrance(.riseIn(0.9), delay: 0)
        .disabled(working)
    }

    /// `.title` + `.sub` (centred in the card, left-aligned in split).
    private func header(centered: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 0) {
            Text(connected == nil ? "Connect to fusionha" : "Welcome back")
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.84)
                .foregroundStyle(Theme.txt)
                .multilineTextAlignment(centered ? .center : .leading)
                .padding(.bottom, 8)
                .loginEntrance(.fadeUp(0.7), delay: 0.42)
            Text(connected == nil ? "Enter the address you open the web app at" : "Sign in to continue")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(centered ? .center : .leading)
                .padding(.bottom, 26)
                .loginEntrance(.fadeUp(0.7), delay: 0.5)
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    @ViewBuilder
    private var content: some View {
        if let connected {
            if connected.status.needsSetup {
                hint("This server hasn't been set up yet. Finish the first-run setup in the web app, then come back.")
                Link("Open the web app", destination: connected.url)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.cyan)
                    .padding(.top, 10)
            } else {
                chooser(url: connected.url, status: connected.status)
                    .frame(maxWidth: .infinity)
                demoSection(url: connected.url, status: connected.status)
            }
        } else {
            serverForm
        }
    }

    /// The brand identity block: logo, the letter-by-letter wordmark, tagline.
    /// The split hero shows it bigger (108pt logo, 20pt wordmark).
    @ViewBuilder
    private func brand(hero: Bool) -> some View {
        let showLogo = status?.loginShowLogo ?? true
        let showWordmark = status?.loginShowWordmark ?? false
        let showTagline = status?.loginShowTagline ?? false
        if showLogo || showWordmark || showTagline {
            VStack(spacing: hero ? 14 : 12) {
                if showLogo {
                    LoginLogo(hero: hero)
                }
                if showWordmark {
                    LoginWordmark(size: hero ? 20 : 15)
                }
                if showTagline {
                    Text("Everything you watch. One library, every quality.")
                        .font(.system(size: 13.5))
                        .lineSpacing(13.5 * 0.6 - 4)
                        .foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.center)
                        .loginEntrance(.fadeUp(0.7), delay: 0.56)
                }
            }
            .padding(.bottom, 22)
        }
    }

    // MARK: Step 1: server

    private var serverForm: some View {
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
    private func chooser(url: URL, status: SetupStatus) -> some View {
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

    private func passwordForm(url: URL) -> some View {
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
    private func plexReveal(url: URL) -> some View {
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
    private func demoSection(url: URL, status: SetupStatus) -> some View {
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

    private func enterDemo(url: URL, credentials: Bool) async {
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
    private var errorText: some View {
        if let error {
            Text(error)
                .font(.system(size: 13))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
                .padding(.bottom, 14)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.dim)
            .multilineTextAlignment(.center)
    }

    // MARK: Actions

    private func pick(_ choice: SignInMethod, url: URL) {
        error = nil
        if choice != .plex { cancelPlex() }
        method = choice
        if choice == .plex && plexPin == nil { Task { await startPlex(url: url) } }
    }

    private func reset() {
        cancelPlex()
        connected = nil
        method = nil
        error = nil
    }

    private func connect() async {
        await run {
            let (url, status) = try await model.connect(server: server)
            withAnimation(.snappy) {
                connected = (url, status)
                method = nil
            }
        }
    }

    private func passwordSignIn(url: URL) async {
        await run { try await model.signIn(server: url, username: username, password: password) }
    }

    private func startPlex(url: URL) async {
        working = true
        error = nil
        defer { working = false }
        do {
            let pin = try await model.startPlexSignIn(server: url)
            guard let auth = URL(string: pin.authUrl) else { throw APIError.http(status: 502, body: "") }
            plexPin = pin
            plexURL = auth
            plexTask = Task {
                do {
                    try await model.completePlexSignIn(server: url, pin: pin) {
                        // Close the Plex sheet first: once signed in this screen goes
                        // away, and a sheet left on a removed view stays on screen.
                        plexURL = nil
                        try? await Task.sleep(for: .milliseconds(450))
                    }
                } catch is CancellationError {
                } catch APIError.http(403, _) {
                    plexURL = nil
                    error = "Your Plex account doesn't have access to this server."
                    model.toast("Your Plex account doesn't have access to this server.", title: "Access denied", variant: .error)
                } catch PlexSignInError.timedOut {
                    plexURL = nil
                    error = "The authorization window expired. Please try again."
                    model.toast("The authorization window expired. Please try again.", title: "Plex sign-in timed out",
                                variant: .error)
                } catch {
                    plexURL = nil
                    self.error = error.localizedDescription
                    model.toast(error.localizedDescription, title: "Plex sign-in failed", variant: .error)
                }
                plexTask = nil
                plexPin = nil
            }
        } catch {
            self.error = "Could not start Plex sign-in"
            model.toast(error.localizedDescription, title: "Could not start Plex sign-in", variant: .error)
        }
    }

    private func cancelPlex() {
        plexTask?.cancel()
        plexTask = nil
        plexPin = nil
        plexURL = nil
    }

    private func run(_ work: () async throws -> Void) async {
        working = true
        error = nil
        defer { working = false }
        do {
            try await work()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Pieces

/// A labelled input styled like the web login's `.field` + `.input`.
private struct LoginField<Input: View>: View {
    let label: String
    @ViewBuilder var input: Input
    var focused: () -> Bool

    var body: some View {
        let isFocused = focused()
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.mut)
            input
                .font(.system(size: 16))
                .foregroundStyle(Theme.txt)
                .tint(Theme.indigo)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color(hex: 0x111319), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isFocused ? Theme.indigo : .white.opacity(0.08)))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.indigo.opacity(isFocused ? 0.25 : 0))
                        .padding(-3))
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .padding(.bottom, 14)
    }
}

/// The web's primary button with the login gradient and a slow sheen.
private struct GradientSubmit: View {
    let title: String
    var workingTitle: String? = nil
    let working: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let shift = (sin(t * .pi / 3) + 1) / 2
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0x3B82F6), location: 0),
                            .init(color: Color(hex: 0x8B5CF6), location: 0.38),
                            .init(color: Color(hex: 0xD946EF), location: 0.66),
                            .init(color: Color(hex: 0xF9A826), location: 1),
                        ],
                        startPoint: UnitPoint(x: -0.3 * shift, y: 0.5),
                        endPoint: UnitPoint(x: 1.6 - 0.3 * shift, y: 0.5))
                }
                if working, let workingTitle {
                    Text(workingTitle).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.bg)
                } else if working {
                    ProgressView().tint(Theme.bg)
                } else {
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.bg)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .disabled(!enabled || working)
        .opacity(enabled ? 1 : 0.55)
    }
}

private struct MethodIcon: View {
    let method: SignInMethod
    var body: some View {
        switch method {
        case .fusionha:
            Image("BrandLogo").resizable().scaledToFit().frame(width: 22, height: 22)
        case .plex:
            Image("plex-mark").resizable().scaledToFit().frame(width: 18, height: 18)
                .foregroundStyle(Theme.plexGold)
        }
    }
}

private extension SignInMethod {
    var label: String { self == .fusionha ? "fusionha" : "Plex" }
}

/// One provider: a single "Continue with …" pill.
private struct SoloMethodButton: View {
    let method: SignInMethod
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                MethodIcon(method: method)
                Text("Continue with \(method.label)")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(method == .plex ? Color(hex: 0xEDC56E) : Theme.txt)
            }
            .padding(.horizontal, 24)
            .frame(height: 52)
            .background(.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

/// Several providers: the segmented pill with a springy sliding indicator.
private struct MethodPill: View {
    let methods: [SignInMethod]
    let selection: SignInMethod?
    let pick: (SignInMethod) -> Void
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(methods, id: \.self) { method in
                Button { pick(method) } label: {
                    HStack(spacing: 9) {
                        MethodIcon(method: method)
                        Text(method.label)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(selection == method ? Theme.txt : Theme.mut)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background {
                        if selection == method {
                            Capsule()
                                .fill(Theme.indigo.opacity(0.26))
                                .overlay(Capsule().strokeBorder(Theme.cyan.opacity(0.4)))
                                .matchedGeometryEffect(id: "indicator", in: indicator)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
        .animation(.spring(duration: 0.32, bounce: 0.35), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}


// MARK: - Entrance choreography (Login.module.css)

enum LoginEntranceKind {
    /// `riseIn`: opacity 0, translateY(22px) scale(.985), cubic-bezier(.16, 1, .3, 1).
    case riseIn(Double)
    /// `fadeUp`: opacity 0, translateY(10px), cubic-bezier(.16, 1, .3, 1).
    case fadeUp(Double)
    /// `letterIn`: opacity 0, translateY(18px) rotate(-8deg), 0.6s cubic-bezier(.34, 1.56, .64, 1).
    case letterIn
}

/// Plays one of the login's CSS entrance keyframes the first time the view
/// appears (after `delay`, `animation-fill-mode: both`). Instant when motion is off.
private struct LoginEntrance: ViewModifier {
    let kind: LoginEntranceKind
    let delay: Double
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    func body(content: Content) -> some View {
        let on = shown || !motion
        content
            .scaleEffect(on ? 1 : startScale)
            .rotationEffect(.degrees(on ? 0 : startRotation))
            .offset(y: on ? 0 : startY)
            .opacity(on ? 1 : 0)
            .onAppear {
                guard motion, !shown else { return }
                withAnimation(animation.delay(delay)) { shown = true }
            }
    }

    private var startY: CGFloat {
        switch kind {
        case .riseIn: return 22
        case .fadeUp: return 10
        case .letterIn: return 18
        }
    }

    private var startScale: CGFloat {
        if case .riseIn = kind { return 0.985 }
        return 1
    }

    private var startRotation: Double {
        if case .letterIn = kind { return -8 }
        return 0
    }

    private var animation: Animation {
        switch kind {
        case .riseIn(let d), .fadeUp(let d): return .timingCurve(0.16, 1, 0.3, 1, duration: d)
        case .letterIn: return .timingCurve(0.34, 1.56, 0.64, 1, duration: 0.6)
        }
    }
}

extension View {
    func loginEntrance(_ kind: LoginEntranceKind, delay: Double) -> some View {
        modifier(LoginEntrance(kind: kind, delay: delay))
    }
}

/// `.logoImg`: an elastic pop on entry (`logoPop` 0.9s, delay 0.12s), then a
/// slow breathe + bob at rest (`logoIdle` 4.2s ease-in-out from 1.2s, forever).
private struct LoginLogo: View {
    let hero: Bool
    @Environment(\.motionEnabled) private var motion
    @State private var popped = false
    @State private var idleStart: Date?

    var body: some View {
        let size: CGFloat = hero ? 108 : 56
        TimelineView(.animation(minimumInterval: nil, paused: idleStart == nil || !motion)) { timeline in
            let pose = idlePose(at: timeline.date)
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255).opacity(hero ? 0.55 : 0.45),
                        radius: hero ? 23 : 15, y: hero ? 16 : 12)
                .scaleEffect(pose.scale)
                .offset(y: pose.y)
        }
        .scaleEffect(popped || !motion ? 1 : 0.6)
        .opacity(popped || !motion ? 1 : 0)
        .accessibilityLabel("fusionha")
        .onAppear {
            guard motion, !popped else { return }
            withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.9).delay(0.12)) { popped = true }
            idleStart = Date().addingTimeInterval(1.2)
        }
    }

    /// `logoIdle` keyframes: 0% (0, 1) · 30% (-4, 1.035) · 55% (-1, 1.01) · 100% (0, 1),
    /// each segment eased with `ease-in-out`.
    private func idlePose(at date: Date) -> (y: CGFloat, scale: CGFloat) {
        guard motion, let idleStart, date > idleStart else { return (0, 1) }
        let p = date.timeIntervalSince(idleStart).truncatingRemainder(dividingBy: 4.2) / 4.2
        let keys: [(at: Double, y: Double, s: Double)] = [(0, 0, 1), (0.3, -4, 1.035), (0.55, -1, 1.01), (1, 0, 1)]
        for i in 1..<keys.count where p <= keys[i].at {
            let a = keys[i - 1], b = keys[i]
            let e = UnitCurve.easeInOut.value(at: (p - a.at) / (b.at - a.at))
            return (CGFloat(a.y + (b.y - a.y) * e), CGFloat(a.s + (b.s - a.s) * e))
        }
        return (0, 1)
    }
}

/// `.wordmark`: "fusionha" uppercase with 0.34em tracking, each letter popping in
/// (`letterIn`, delay 0.34s + i × 0.05s); the last two letters carry the gradient.
private struct LoginWordmark: View {
    let size: CGFloat
    private static let letters = "FUSIONHA".map { String($0) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.letters.indices, id: \.self) { i in
                Group {
                    if i >= 6 {
                        Text(Self.letters[i]).foregroundStyle(Theme.loginGradient)
                    } else {
                        Text(Self.letters[i]).foregroundStyle(Theme.txt)
                    }
                }
                .font(.system(size: size, weight: .semibold))
                .tracking(size * 0.34)
                .loginEntrance(.letterIn, delay: 0.34 + Double(i) * 0.05)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("fusionha")
    }
}

/// A one-column CSS grid with `min-height: 100%`: each row gets its natural
/// height and the spare height is shared equally (auto tracks stretch).
private struct StretchRows: Layout {
    var minHeight: CGFloat

    private func heights(_ width: CGFloat?, _ subviews: Subviews) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width
        let total = heights(width, subviews).reduce(0, +)
        return CGSize(width: width ?? 0, height: max(minHeight, total))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = heights(bounds.width, subviews)
        let extra = subviews.isEmpty ? 0 : max(0, bounds.height - rows.reduce(0, +)) / CGFloat(subviews.count)
        var y = bounds.minY
        for (i, subview) in subviews.enumerated() {
            let height = rows[i] + extra
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height
        }
    }
}
