import SwiftUI
import FusionhaKit

/// First-run setup (web `routes/Setup.tsx`): Welcome → create the admin →
/// connect TMDB → the root layout → import an existing library → done. The
/// admin step signs in with a session cookie; the device token is minted on
/// Enter, so nothing switches to the app behind the wizard.
struct SetupWizardView: View {
    let server: URL
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var session: APIClient?
    @State private var username = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var tmdbKey = ""
    @State private var working = false
    @State private var error: String?

    private let steps = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            progress
            Group {
                switch step {
                case 0: welcome
                case 1: admin
                case 2: tmdb
                case 3: roots
                case 4: importStep
                default: done
                }
            }
            .id(step)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: step)
        .disabled(working)
        .interactiveDismissDisabled(session != nil)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps, id: \.self) { i in
                Capsule().fill(i <= step ? Theme.i1 : Theme.line).frame(height: 4)
            }
        }
        .accessibilityLabel("Step \(step + 1) of \(steps)")
    }

    private func head(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Theme.display(34)).foregroundStyle(Theme.txt)
            Text(text).font(.body).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nav(back: Int? = nil, skip: (() -> Void)? = nil, link: (title: String, panel: String)? = nil,
                     primary: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        // The web's single nav row; on a narrow phone the settings link drops
        // to its own row under it instead of squeezing the buttons.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                navRow(back: back, skip: skip, primary: primary, enabled: enabled, action: action, link: link)
            }
            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    navRow(back: back, skip: skip, primary: primary, enabled: enabled, action: action, link: nil)
                }
                if let link { linkButton(link) }
            }
        }
    }

    @ViewBuilder
    private func navRow(back: Int?, skip: (() -> Void)?, primary: String, enabled: Bool,
                        action: @escaping () -> Void, link: (title: String, panel: String)?) -> some View {
        if let back { Button("Back") { error = nil; step = back }.buttonStyle(ActButtonStyle(kind: .ghost, small: false)) }
        Spacer(minLength: 0)
        if let skip { Button("Skip", action: skip).buttonStyle(ActButtonStyle(kind: .subtle, small: false)) }
        if let link { linkButton(link) }
        Button(primary, action: action).buttonStyle(ActButtonStyle(kind: .primary, small: false)).disabled(!enabled)
    }

    /// Signs in, then opens a Settings panel (web `Link to="/settings/…"`).
    private func linkButton(_ link: (title: String, panel: String)) -> some View {
        Button(link.title) { Task { await enter(openingSettings: link.panel) } }
            .buttonStyle(ActButtonStyle(kind: .subtle, small: false))
            .disabled(session == nil)
            .fixedSize()
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            head("Welcome to fusionha", "One library for movies, series and anime, every title tracked in HD and 4K at once. Let’s get set up in a minute.")
            nav(primary: "Get started") { step = 1 }
            Button("Cancel") { dismiss() }.font(.footnote).foregroundStyle(Theme.mut)
        }
    }

    private var admin: some View {
        VStack(alignment: .leading, spacing: 18) {
            head("Create your admin account", "This account can change every setting. You can add more people later in Settings › Users.")
            VStack(spacing: 10) {
                field(TextField("Username", text: $username).textContentType(.username))
                field(SecureField("Password", text: $password).textContentType(.newPassword))
                field(SecureField("Confirm password", text: $confirm).textContentType(.newPassword))
            }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
            nav(primary: working ? "Creating…" : "Create admin",
                enabled: !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty) {
                Task { await createAdmin() }
            }
        }
    }

    private var tmdb: some View {
        VStack(alignment: .leading, spacing: 18) {
            head("Connect TMDB", "fusionha uses TMDB for movie and series metadata (with TVDB and IMDB to TMDB translation for arr clients). Without it, Discover, search and movies won’t work. You can add it later in Settings › Metadata.")
            field(TextField("Paste your TMDB API key", text: $tmdbKey))
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
            nav(skip: { error = nil; step = 3 }, primary: working ? "Saving…" : "Continue") { Task { await saveTmdb() } }
        }
    }

    private var roots: some View {
        VStack(alignment: .leading, spacing: 18) {
            head("Add root folders", "Separate roots per tier: HD and 4K live apart, so both versions of a title can be tracked at once. Manage root folders signs you in and opens them, or add them in Settings › Root Folders later.")
            ActFlow(spacing: 8, lineSpacing: 8) {
                ForEach(SetupTierPaths.all, id: \.self) { path in
                    Text(path)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(path.hasSuffix("-4k") ? Theme.i2 : Theme.i1)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background((path.hasSuffix("-4k") ? Theme.i2 : Theme.i1).opacity(0.14), in: .capsule)
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
            nav(back: 2, link: ("Manage root folders", "roots"), primary: "Continue") { step = 4 }
        }
    }

    private var importStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            head("Import existing library", "Already have a collection? Settings › Import Library points fusionha at a root and matches your folders to TMDB. Override any match before importing.")
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
            nav(back: 3, skip: { step = 5 }, primary: "Scan a root now", enabled: session != nil) {
                Task { await enter(openingSettings: "import") }
            }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 18) {
            head("You’re all set", "fusionha is ready. Your virtual arr instances (Radarr-HD/4K, Sonarr-HD/4K) are live for Overseerr and Prowlarr to connect to.")
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
            nav(primary: working ? "Signing in…" : "Enter fusionha") { Task { await enter() } }
        }
    }

    private func field(_ content: some View) -> some View {
        content
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.panel, in: .rect(cornerRadius: 12))
    }

    // MARK: Actions

    private func createAdmin() async {
        guard password == confirm else { error = "The passwords don’t match."; return }
        working = true
        defer { working = false }
        do {
            session = try await model.createFirstAdmin(server: server, username: username.trimmingCharacters(in: .whitespaces), password: password)
            error = nil
            step = 2
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t create the admin. Try again.")
        }
    }

    private func saveTmdb() async {
        let key = tmdbKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { step = 3; return }
        working = true
        defer { working = false }
        do {
            try await session?.saveTmdbKey(key)
            error = nil
            step = 3
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t save the key. Check it, or skip for now.")
        }
    }

    /// Signs in and, for the roots and import links (web `/settings/roots`,
    /// `/settings/import`), opens that Settings panel once the app is up.
    private func enter(openingSettings panel: String? = nil) async {
        guard let session else { return }
        working = true
        defer { working = false }
        do {
            try await model.enterAfterSetup(session)
            if let panel {
                model.avatar.settingsPanel = panel
                model.avatar.showingSettings = true
            }
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t sign in. Close this and sign in with your new admin.")
        }
    }
}
