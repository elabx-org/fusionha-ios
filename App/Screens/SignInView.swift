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
    @State private var appeared = false
    @FocusState private var field: Field?

    enum Field { case server, username, password }

    private var status: SetupStatus? { connected?.status }

    var body: some View {
        ZStack {
            LoginBackdrop(mode: status?.loginBackground ?? "aurora")
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 18) {
                    card
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
                .frame(maxWidth: 384)
                .padding(.horizontal, 26)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $plexURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        .onAppear { withAnimation(.spring(duration: 0.9, bounce: 0.25)) { appeared = true } }
        #if DEBUG
        .task {
            // CI screenshots: connect to the mock server and pick a method.
            let env = ProcessInfo.processInfo.environment
            guard let login = env["FUSIONHA_SCREENSHOT_LOGIN"], !login.isEmpty else { return }
            server = login
            await connect()
            if env["FUSIONHA_SCREENSHOT_METHOD"] == "fusionha" { method = .fusionha }
        }
        #endif
    }

    // MARK: Card

    private var card: some View {
        VStack(spacing: 0) {
            brand
            Text(connected == nil ? "Connect to fusionha" : "Welcome back")
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.84)
                .foregroundStyle(Theme.txt)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            Text(connected == nil ? "Enter the address you open the web app at" : "Sign in to continue")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
                .padding(.bottom, 26)

            if let connected {
                if connected.status.needsSetup {
                    hint("This server hasn't been set up yet. Finish the first-run setup in the web app, then come back.")
                    Link("Open the web app", destination: connected.url)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.cyan)
                        .padding(.top, 10)
                } else {
                    chooser(url: connected.url, status: connected.status)
                }
            } else {
                serverForm
            }
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
        .offset(y: appeared ? 0 : 22)
        .scaleEffect(appeared ? 1 : 0.985)
        .opacity(appeared ? 1 : 0)
        .disabled(working)
    }

    @ViewBuilder
    private var brand: some View {
        let showLogo = status?.loginShowLogo ?? true
        let showWordmark = status?.loginShowWordmark ?? false
        let showTagline = status?.loginShowTagline ?? false
        if showLogo || showWordmark || showTagline {
            VStack(spacing: 12) {
                if showLogo {
                    Image("BrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255).opacity(0.45), radius: 15, y: 12)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .phaseAnimator([0, 1]) { view, phase in
                            view.offset(y: phase == 1 ? -3 : 0)
                        } animation: { _ in .easeInOut(duration: 2.1) }
                        .accessibilityLabel("fusionha")
                }
                if showWordmark {
                    HStack(spacing: 0) {
                        Text("FUSION").foregroundStyle(Theme.txt)
                        Text("HA").foregroundStyle(Theme.loginGradient)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(5.1)
                }
                if showTagline {
                    Text("Everything you watch. One library, every quality.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.center)
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
            hint("No sign-in methods are enabled. Ask your admin to turn one on.")
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
                    case .fusionha: passwordForm(url: url)
                    case .plex: plexReveal(url: url)
                    case nil:
                        if methods.count > 1 { hint("Choose a method above to continue").padding(.top, 18) }
                    }
                }
                .transition(.opacity.combined(with: .offset(y: 8)))
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
            GradientSubmit(title: "Sign in", working: working, enabled: !username.isEmpty && !password.isEmpty) {
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
            }
            errorText
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
        await run {
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
                } catch {
                    plexURL = nil
                    self.error = error.localizedDescription
                }
                plexTask = nil
                plexPin = nil
            }
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
                if working {
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

/// The login backdrops (components/login/backdrops.ts): aurora (default), grid,
/// gradient, solid. The canvas-heavy ones fall back to aurora.
struct LoginBackdrop: View {
    let mode: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x101423), Color(hex: 0x07080C)],
                           center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: 900)
            switch mode {
            case "solid", "none":
                EmptyView()
            case "gradient":
                LinearGradient(colors: [Color(hex: 0x2B2F66), Color(hex: 0x123B46)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Theme.cyan.opacity(0.14), .clear], center: UnitPoint(x: 0.5, y: 0.4),
                               startRadius: 0, endRadius: 500)
            case "grid":
                animated { context, size, t in
                    let width = Double(size.width), height = Double(size.height)
                    let gap = max(16, (width / 16).rounded())
                    var y = gap / 2
                    var row = 0
                    while y < height {
                        var x = gap / 2
                        var col = 0
                        while x < width {
                            let phase = Double((row * 31 + col * 17) % 628) / 100
                            let alpha = 0.12 + 0.12 * sin(t * 2 + phase)
                            let mix = x / width
                            let color = Color(red: (99 + (34 - 99) * mix) / 255, green: (102 + (211 - 102) * mix) / 255,
                                              blue: (241 + (238 - 241) * mix) / 255)
                            context.fill(Path(ellipseIn: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)),
                                         with: .color(color.opacity(alpha)))
                            x += gap
                            col += 1
                        }
                        y += gap
                        row += 1
                    }
                }
            default:
                animated { context, size, t in
                    let w = Double(size.width), h = Double(size.height), mn = min(w, h)
                    func blob(_ x: Double, _ y: Double, _ r: Double, _ color: Color) {
                        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                        context.fill(Path(ellipseIn: rect),
                                     with: .radialGradient(Gradient(colors: [color, .clear]),
                                                           center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
                    }
                    let ms = t * 1000
                    blob(w * 0.32 + sin(ms * 0.0006) * w * 0.08, h * 0.36 + cos(ms * 0.0005) * h * 0.12, mn * 0.72,
                         Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255).opacity(0.5))
                    blob(w * 0.7 + cos(ms * 0.0007) * w * 0.08, h * 0.66 + sin(ms * 0.0006) * h * 0.12, mn * 0.66,
                         Color(red: 34 / 255, green: 211 / 255, blue: 238 / 255).opacity(0.45))
                }
            }
            // The edge vignette that unifies the layers.
            RadialGradient(stops: [.init(color: .clear, location: 0.4), .init(color: .black.opacity(0.55), location: 1)],
                           center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 700)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func animated(_ draw: @escaping (GraphicsContext, CGSize, Double) -> Void) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                draw(context, size, timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000))
            }
        }
    }
}
