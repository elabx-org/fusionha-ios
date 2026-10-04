import SwiftUI
import FusionhaKit

/// Settings → Appearance (the web's `AppearancePanel.tsx`): a segmented
/// control over Theme · Login screen · Library display · Top bar; each
/// section autosaves. Sections cross-fade with a 4pt rise (0.18s), instant
/// when motion is off.
struct AppearanceSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var tab = "theme"

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

    private static let backgrounds: [(key: String, name: String, animated: Bool)] = [
        ("flow", "Flow", true), ("web", "Web", true), ("hub", "Hub", true), ("orbits", "Orbits", true),
        ("grid", "Grid", true), ("aurora", "Aurora", true), ("gradient", "Gradient", false),
        ("solid", "Solid", false), ("none", "None", false),
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
    }

    private var tabBinding: Binding<String> {
        Binding(get: { tab }, set: { next in
            SettingsMotion.perform(motionOff, .timingCurve(0.4, 0, 0.2, 1, duration: 0.18)) { tab = next }
        })
    }

    // MARK: Theme

    @ViewBuilder
    private var themeSection: some View {
        SettingsSection("Accent theme") {
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

    @ViewBuilder
    private var loginSection: some View {
        SettingsSection("Login layout") {
            SettingPicker(label: "Login layout", description: "Where the sign-in form sits.",
                          options: [("centered", "Centered"), ("split", "Split")],
                          selection: store.stringBinding("login_layout", "centered"))
        }
        SettingsSection("Login elements") {
            SettingToggle(key: "login_show_logo", label: "Show logo",
                          description: "The fusionha mark on the login screen.", fallback: true)
            SettingToggle(key: "login_show_wordmark", label: "Show app name",
                          description: "The “fusionha” wordmark under the logo.")
            SettingToggle(key: "login_show_tagline", label: "Show tagline",
                          description: "A one-line description (shown only to signed-out visitors when on).")
        }
        SettingsSection("Login background",
                        footer: "Changes save immediately and apply to everyone at the sign-in screen. Reduced-motion visitors always get a still version.") {
            let active = store.string("login_background", "aurora")
            ForEach(Self.backgrounds, id: \.key) { bg in
                Button {
                    store.save("login_background", .string(bg.key))
                } label: {
                    HStack {
                        Text(bg.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        Text(bg.animated ? "Animated" : "Static")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(bg.animated ? Theme.cyan : Theme.dim)
                        Spacer()
                        if bg.key == active {
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.cyan)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .settingsField("Login background")
    }

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
