import SwiftUI
import FusionhaKit

/// Settings → Appearance (the web's `AppearancePanel.tsx`): a segmented
/// control over Theme · Login screen · Library display · Top bar; each
/// section autosaves. Sections cross-fade with a 4pt rise (0.18s), instant
/// when motion is off.
struct AppearanceSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @Environment(SettingsFlash.self) private var flash
    @State private var tab = AppearanceSettingsPanel.initialTab

    #if DEBUG
    /// CI screenshots: `FUSIONHA_SCREENSHOT_APPEARANCE_TAB=login` opens a section.
    private static var initialTab: String {
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_APPEARANCE_TAB"] ?? "theme"
    }
    #else
    private static let initialTab = "theme"
    #endif

    private static let accents: [(key: String, name: String, i1: UInt32, i2: UInt32)] = [
        ("aurora", "Aurora", 0x6366F1, 0x22D3EE),
        ("violet", "Violet", 0x7C5CFF, 0x9D7BFF),
        ("blue", "Blue", 0x3B82F6, 0x60A5FA),
        ("rose", "Rose", 0xF43F5E, 0xFB7185),
        ("amber", "Amber", 0xF59E0B, 0xFBBF24),
        ("indigo", "Indigo", 0x6366F1, 0x818CF8),
        ("cyan", "Cyan", 0x06B6D4, 0x22D3EE),
        ("fuchsia", "Fuchsia", 0xC026D3, 0xE879F9),
    ]

    var body: some View {
        SettingsForm(slug: "appearance") {
            Section {
                Picker("Appearance section", selection: tabBinding) {
                    Text("Theme").tag("theme")
                    Text("Login screen").tag("login")
                    Text("Library display").tag("library")
                    Text("Top bar").tag("topbar")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // This iPhone's colours never wait on the server's settings.
            if tab == "theme" {
                AppPaletteSection()
                DuoOpenLayoutSection()
            }
            if store.loaded {
                Group {
                    switch tab {
                    case "login": loginSection
                    case "library": librarySection
                    case "topbar": topBarSection
                    default: themeSection
                    }
                }
                .transition(motionOff ? .identity : .opacity.combined(with: .offset(y: 4)))
            } else {
                SettingsLoadingRow()
            }
        }
        #if DEBUG
        .task(id: store.loaded) {
            // CI screenshots: scroll to a field (`FUSIONHA_SCREENSHOT_APPEARANCE_SCROLL=Login background`).
            guard store.loaded, let label = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_APPEARANCE_SCROLL"]
            else { return }
            try? await Task.sleep(for: .milliseconds(600))
            flash.set(panel: "appearance", label: label)
        }
        #endif
    }

    private var tabBinding: Binding<String> {
        Binding(get: { tab }, set: { next in
            SettingsMotion.perform(motionOff, .timingCurve(0.4, 0, 0.2, 1, duration: 0.18)) { tab = next }
        })
    }

    // MARK: Theme

    @ViewBuilder
    private var themeSection: some View {
        SettingsSection("Web accent theme", footer: "The web app's accent, for everyone who uses it. The iPhone's colours are set above.") {
            let active = store.string("ui_theme", "aurora")
            ForEach(Self.accents, id: \.key) { theme in
                Button {
                    if theme.key != active { store.save("ui_theme", .string(theme.key)) }
                } label: {
                    HStack(spacing: 12) {
                        HStack(spacing: 0) {
                            Color(hex: theme.i1)
                            Color(hex: theme.i2)
                        }
                        .frame(width: 30, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        Text(theme.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                        Spacer()
                        if theme.key == active {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(hex: theme.i2))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .contentShape(Rectangle())
                    .animation(.easeInOut(duration: 0.2), value: active)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(theme.key == active ? .isSelected : [])
            }
        }
        .settingsField("Accent theme")
        SettingsSection("Login screen") {
            Text("The sign-in screen’s layout, background, and branding are in the “Login screen” tab above.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
        }
    }

    // MARK: Login

    /// The web's `LoginCustomisePanel`: a live preview, the two layout tiles,
    /// the branding switches and the live thumbnail grid of backgrounds.
    @ViewBuilder
    private var loginSection: some View {
        let stored = store.string("login_layout", "centered")
        let layout = ["split", "living"].contains(stored) ? stored : "centered"
        let living = layout == "living"
        let background = BackdropMode(resolving: store.string("login_background", "aurora"))
        SettingsSection("Preview") {
            VStack(alignment: .leading, spacing: 12) {
                Text(living ? "Living logo" : "\(layout == "split" ? "Split" : "Centered") · \(background.name)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                LoginPreview(layout: layout, background: background, motionOff: motionOff,
                             showLogo: store.bool("login_show_logo", true),
                             showWordmark: store.bool("login_show_wordmark"),
                             showTagline: store.bool("login_show_tagline"))
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 4, trailing: 8))
            .listRowBackground(Color.clear)
        }
        SettingsSection("Login layout") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where the sign-in form sits.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                ForEach(Self.layouts, id: \.key) { option in
                    LayoutTile(key: option.key, name: option.name, desc: option.desc, selected: layout == option.key) {
                        if layout != option.key { store.save("login_layout", .string(option.key)) }
                    }
                }
            }
            .id("Login layout")
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 4, trailing: 8))
            .listRowBackground(Color.clear)
        }
        SettingsSection("Login elements") {
            SettingToggle(key: "login_show_logo", label: "Show logo",
                          description: "The fusionha mark on the login screen.", fallback: true)
            SettingToggle(key: "login_show_wordmark", label: "Show app name",
                          description: "The “fusionha” wordmark under the logo.")
            SettingToggle(key: "login_show_tagline", label: "Show tagline",
                          description: "A one-line description (shown only to signed-out visitors when on).")
        }
        SettingsSection("Living logo") {
            Text(living ? "Neutral moves by default." : "Used by the Living logo layout.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
            SettingToggle(key: "login_living_media", label: "Media morphs on the sign-in page",
                          description: "Adds film, TV and anime-themed animations (a clapperboard, an old TV, a dragon…). Off by default: they tell signed-out visitors this server manages media.")
                .disabled(!living)
        }
        SettingsSection("Login background",
                        footer: "Changes save immediately and apply to everyone at the sign-in screen. Reduced-motion visitors always get a still version.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Animated or static. All respect reduced-motion.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                if living {
                    Text("Living logo draws its own dot field, so the background doesn’t apply. Your choice is kept for the other layouts.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                        ForEach(BackdropMode.allCases) { mode in
                            BackgroundTile(mode: mode, selected: background == mode, motionOff: motionOff) {
                                if background != mode { store.save("login_background", .string(mode.rawValue)) }
                            }
                        }
                    }
                }
            }
            .id("Login background")
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.clear)
        }
    }

    private static let layouts: [(key: String, name: String, desc: String)] = [
        ("centered", "Centered", "Glass card over a full-screen background."),
        ("split", "Split", "Animated hero beside a solid form panel."),
        ("living", "Living logo", "The logo comes alive beside the form and reacts as you type."),
    ]

    // MARK: Library display

    @ViewBuilder
    private var librarySection: some View {
        SettingsSection {
            SettingPicker(label: "Coverage rails", description: railHint,
                          options: [("current", "Current"), ("fill", "Fill only"), ("dot", "Trailing dot")],
                          selection: store.stringBinding("library_rail_style", "current"))
            SettingToggle(key: "library_rail_consolidate", label: "Consolidate HD + 4K",
                          description: "When one edition has both HD and 4K complete on disk, show a single HD·4K combo rail. A tier that is missing, wanted, or downloading always stays its own rail.")
        }
    }

    private var railHint: String {
        switch store.string("library_rail_style", "current") {
        case "fill": return "A softly-glowing full bar reads complete — size or count, no ✓."
        case "dot": return "The ✓ / count becomes a small coloured status dot."
        default: return "Tier pill · fill bar · ✓ / count / date — today’s rail."
        }
    }

    // MARK: Top bar

    @ViewBuilder
    private var topBarSection: some View {
        SettingsSection {
            VStack(alignment: .leading, spacing: 10) {
                FieldLabel(label: "Status readout",
                           description: "How the top-bar Activity, caution and connection signals are framed. HUD is a squared instrument tray; Bracket is a corner-bracket frame — neither is a pill, so it never mirrors the centre nav.")
                Picker("Status readout", selection: store.stringBinding("topbar_status_style", "hud")) {
                    Text("HUD readout").tag("hud")
                    Text("Bracket").tag("bracket")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .settingsField("Status readout")
        }
    }
}
