import SwiftUI
import FusionhaKit

enum SignInMethod: Hashable {
    case fusionha, plex
}

/// The web login page (routes/Login.tsx) rebuilt natively: the animated
/// backdrop the admin picked, the glass card with the fusionha logo,
/// "Welcome back", the method pill (fusionha / Plex) and the reveal below it.
/// The app first asks for the server address on the same stage (F2): the
/// Living logo acts out finding it, then the stage cross-fades into that
/// server's own login look.
struct SignInView: View {
    @Environment(AppModel.self) var model
    /// Never pre-filled and never a default server (fusionha #65).
    @State var server = ServerMemory().initialAddress
    @State var connected: ServerProbe?
    @State var failure: ConnectFailure?
    @State var recents: [RememberedServer] = []
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
    /// Bumped on a failed step in the Living layout: the form shakes "no".
    @State var nudges = 0
    /// The native first-run setup for a fresh server.
    @State var settingUp = false
    /// The stage's width: past 720 / 760 the art sits beside the form (DU15).
    @State var stageWidth: CGFloat = 0

    enum Field { case server, username, password, demoUser, demoPass }

    var memory: ServerMemory { ServerMemory() }
    var status: SetupStatus? { connected?.status }

    /// Reduce Motion, or the server's `animations_enabled` when the app still
    /// knows it (setup-status doesn't carry it, so a fresh sign-in animates).
    var motionOff: Bool { reduceMotion || !model.animationsEnabled }

    /// The look the stage shows: the connected server's; before that, the last
    /// server this phone reached (its cached look); on a fresh install, the
    /// Living logo over the default backdrop.
    var look: LoginLook {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        let layout = env["FUSIONHA_SCREENSHOT_LOGIN_LAYOUT"].flatMap { $0.isEmpty ? nil : $0 }
        let background = env["FUSIONHA_SCREENSHOT_LOGIN_BACKGROUND"].flatMap { $0.isEmpty ? nil : $0 }
        if layout != nil || background != nil, connected != nil {
            return LoginLook(layout: layout ?? status?.loginLayout, background: background ?? status?.loginBackground,
                             cached: false)
        }
        #endif
        if let status { return LoginLook(layout: status.loginLayout, background: status.loginBackground, cached: false) }
        if let last = recents.first {
            return LoginLook(layout: last.loginLayout, background: last.loginBackground, cached: true)
        }
        return .firstRun
    }

    /// `login_background` (unknown → aurora, like `resolveBackground`).
    var backdropMode: BackdropMode { BackdropMode(resolving: look.background) }

    /// `login_layout`: "split" puts the backdrop in a hero above a solid form
    /// panel (the web's ≤760px split); anything else is the centered card.
    var isSplit: Bool { look.layout == "split" }

    /// `login_layout = living`: the animated Living logo art panel above the form.
    var isLiving: Bool { look.layout == "living" }

    var body: some View {
        ZStack {
            CSSRadialGradient.stage.ignoresSafeArea()
            Group {
                if isLiving {
                    livingStage
                } else if isSplit {
                    splitStage
                } else {
                    centeredStage
                }
            }
            .id(look.layout ?? "centered")
            .transition(.opacity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stageWidth = $0 }
        .animation(motionOff ? nil : .easeInOut(duration: 0.5), value: look)
        // On a half-open Duo the toasts keep to the trailing side of the fold (DC14).
        .overlay { FoldToastLayer() }
        .environment(\.motionEnabled, !motionOff)
        .preferredColorScheme(.dark)
        .sheet(item: $plexURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        .onAppear {
            memory.dropLegacyAddress()
            recents = memory.recents
            living.setMedia(recents.first?.livingMedia == true)
        }
        #if DEBUG
        .task {
            // CI screenshots: connect to the mock server and pick a method.
            let env = ProcessInfo.processInfo.environment
            // Landscape sign-in shots (the shell's hook doesn't run signed out).
            if env["FUSIONHA_SCREENSHOT_ORIENTATION"] == "landscape",
               let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
            }
            guard let login = env["FUSIONHA_SCREENSHOT_LOGIN"], !login.isEmpty else { return }
            server = login
            await connect()
            if env["FUSIONHA_SCREENSHOT_METHOD"] == "fusionha" { method = .fusionha }
            if env["FUSIONHA_SCREENSHOT_METHOD"] == "demo" { demoOpen = true }
        }
        #endif
    }
}

/// Which login look the stage shows, and where it came from.
struct LoginLook: Equatable {
    var layout: String?
    var background: String?
    /// From a remembered server, before this connect answered.
    var cached: Bool

    /// A fresh install: the Living logo over the default (aurora) backdrop.
    static let firstRun = LoginLook(layout: "living", background: nil, cached: false)
}
