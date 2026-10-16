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
    @Environment(AppModel.self) var model
    @AppStorage("lastServer") var server = ""
    @State var connected: (url: URL, status: SetupStatus)?
    @State var method: SignInMethod?
    @State var username = ""
    @State var password = ""
    @State var working = false
    @State var error: String?
    @State var plexURL: URL?
    @State var plexPin: PlexPin?
    @State var plexTask: Task<Void, Never>?
    @State var demoOpen = false
    @State var demoUser = ""
    @State var demoPass = ""
    @FocusState var field: Field?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    /// The Living logo layout's engine (tumbler pins, jam, unlock).
    @State var living = LivingEngine()
    /// Bumped on a failed sign-in in the Living layout: the form shakes "no".
    @State var nudges = 0
    /// The native first-run setup for a fresh server.
    @State var settingUp = false

    enum Field { case server, username, password, demoUser, demoPass }

    var status: SetupStatus? { connected?.status }

    /// Reduce Motion, or the server's `animations_enabled` when the app still
    /// knows it (setup-status doesn't carry it, so a fresh sign-in animates).
    var motionOff: Bool { reduceMotion || !model.animationsEnabled }

    /// `login_background` (unknown → aurora, like `resolveBackground`).
    var backdropMode: BackdropMode {
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_LOGIN_BACKGROUND"], !forced.isEmpty {
            return BackdropMode(resolving: forced)
        }
        #endif
        return BackdropMode(resolving: status?.loginBackground)
    }

    /// `login_layout`: "split" puts the backdrop in a hero above a solid form
    /// panel (the web's ≤760px split); anything else is the centered card.
    var isSplit: Bool { layout == "split" }

    /// `login_layout = living`: the animated Living logo art panel above the form.
    /// It needs the server's settings, so the address step stays the centred card.
    var isLiving: Bool { connected != nil && layout == "living" }

    var layout: String? {
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_LOGIN_LAYOUT"], !forced.isEmpty {
            return forced
        }
        #endif
        return status?.loginLayout
    }

    var body: some View {
        ZStack {
            CSSRadialGradient.stage.ignoresSafeArea()
            if isLiving {
                livingStage
            } else if isSplit {
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
    var centeredStage: some View {
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
    var splitStage: some View {
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

                    formPanel(top: false)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea(.container)
    }

    /// `.formPanel` on phones: the solid panel under the hero, with a hairline on top.
    func formPanel(top: Bool, minHeight: CGFloat = 0) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 0) {
                header(centered: false)
                content
            }
            .disabled(working)
            .modifier(Nudge(trigger: nudges))
            changeServer
        }
        .frame(maxWidth: 340)
        .padding(.horizontal, 30)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: top ? .top : .center)
        .background(LinearGradient(colors: [Color(red: 19 / 255, green: 21 / 255, blue: 28 / 255).opacity(0.98),
                                            Color(red: 12 / 255, green: 13 / 255, blue: 18 / 255).opacity(0.99)],
                                   startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }

    /// `[data-layout='living']` on phones: the Living logo art takes the top 44%
    /// of the screen and the form sits below it (its own dot field, so
    /// `login_background` does not apply). Only the wordmark/tagline toggles
    /// apply under the mark: the mark IS the logo.
    var livingStage: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    LivingMark(engine: living, reduce: motionOff) {
                        livingCaption
                    }
                    .frame(height: geo.size.height * 0.44)
                    // `place-items: start center` under the art.
                    formPanel(top: true, minHeight: geo.size.height * 0.56)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea(.container)
        .onChange(of: password) { if isLiving { living.typing(password.count) } }
        .onChange(of: field) { old, new in
            guard isLiving else { return }
            if new == .password { living.listen() } else if old == .password { living.unlisten() }
        }
    }

    @ViewBuilder
    var livingCaption: some View {
        let showWordmark = status?.loginShowWordmark ?? false
        let showTagline = status?.loginShowTagline ?? false
        if showWordmark || showTagline {
            VStack(spacing: 8) {
                if showWordmark { LoginWordmark(size: 15) }
                if showTagline {
                    Text("Everything you watch. One library, every version.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 14)
        }
    }

    @ViewBuilder
    var changeServer: some View {
        if let connected {
            Button {
                withAnimation(.snappy) { reset() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                    Text(connected.url.host() ?? connected.url.absoluteString)
                    Text("·")
                    Text("Change").foregroundStyle(Theme.txt)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.mut)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Card

    var card: some View {
        VStack(spacing: 0) {
            brand(hero: false)
            header(centered: true)
            content
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        // A Liquid Glass sheet over the living backdrop, darkened so the form reads.
        .glassEffect(.regular.tint(Theme.bg.opacity(0.62)), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.8), radius: 50, y: 36)
        // `.card { animation: riseIn 0.9s }`
        .loginEntrance(.riseIn(0.9), delay: 0)
        .disabled(working)
    }

    /// `.title` + `.sub` (centred in the card, left-aligned in split).
    func header(centered: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 0) {
            Text(connected == nil ? "Connect to fusionha" : "Welcome back")
                .font(Theme.display(40))
                .tracking(Theme.displayTracking(40))
                .foregroundStyle(Theme.txt)
                .multilineTextAlignment(centered ? .center : .leading)
                .padding(.bottom, 8)
                .loginEntrance(.fadeUp(0.7), delay: 0.42)
            Text(connected == nil ? "Enter the address you open the web app at" : "Sign in to continue")
                .font(.system(size: 15))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(centered ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 26)
                .loginEntrance(.fadeUp(0.7), delay: 0.5)
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    @ViewBuilder
    var content: some View {
        if let connected {
            if connected.status.needsSetup {
                hint("This server hasn't been set up yet. Create its admin account and connect TMDB here.")
                Button("Set up this server") { settingUp = true }
                    .buttonStyle(ActButtonStyle(kind: .primary, small: false))
                    .padding(.top, 10)
                    .fullScreenCover(isPresented: $settingUp) { SetupWizardView(server: connected.url) }
                Link("Or open the web app", destination: connected.url)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .padding(.top, 8)
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
    func brand(hero: Bool) -> some View {
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
                    Text("Everything you watch. One library, every version.")
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

}
