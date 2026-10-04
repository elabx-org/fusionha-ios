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

    /// The web's `LoginCustomisePanel`: a live preview, the two layout tiles,
    /// the branding switches and the live thumbnail grid of backgrounds.
    @ViewBuilder
    private var loginSection: some View {
        let layout = store.string("login_layout", "centered") == "split" ? "split" : "centered"
        let background = BackdropMode(resolving: store.string("login_background", "aurora"))
        SettingsSection("Preview") {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(layout == "split" ? "Split" : "Centered") · \(background.name)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                LoginPreview(layout: layout, background: background, motionOff: motionOff,
                             showLogo: store.bool("login_show_logo", true),
                             showWordmark: store.bool("login_show_wordmark"),
                             showTagline: store.bool("login_show_tagline"))
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
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
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
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
        SettingsSection("Login background",
                        footer: "Changes save immediately and apply to everyone at the sign-in screen. Reduced-motion visitors always get a still version.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Animated or static. All respect reduced-motion.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                    ForEach(BackdropMode.allCases) { mode in
                        BackgroundTile(mode: mode, selected: background == mode, motionOff: motionOff) {
                            if background != mode { store.save("login_background", .string(mode.rawValue)) }
                        }
                    }
                }
            }
            .id("Login background")
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
            .listRowBackground(Color.clear)
        }
    }

    private static let layouts: [(key: String, name: String, desc: String)] = [
        ("centered", "Centered", "Glass card over a full-screen background."),
        ("split", "Split", "Animated hero beside a solid form panel."),
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

// MARK: - Login screen pieces

/// The live preview (`.preview`): the chosen backdrop behind a wireframe of the
/// login, centered card or split hero + form side, reflecting the toggles.
private struct LoginPreview: View {
    let layout: String
    let background: BackdropMode
    let motionOff: Bool
    let showLogo: Bool
    let showWordmark: Bool
    let showTagline: Bool

    private static let cardFill = LinearGradient(
        colors: [Color(red: 23 / 255, green: 26 / 255, blue: 35 / 255).opacity(0.82),
                 Color(red: 17 / 255, green: 19 / 255, blue: 26 / 255).opacity(0.9)],
        startPoint: .top, endPoint: .bottom)
    private static let formFill = LinearGradient(
        colors: [Color(red: 20 / 255, green: 22 / 255, blue: 29 / 255).opacity(0.97),
                 Color(red: 13 / 255, green: 14 / 255, blue: 19 / 255).opacity(0.99)],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                Theme.panel
                BackdropCanvas(mode: background, motionOff: motionOff)
                CSSRadialGradient.previewVeil
                if layout == "split" {
                    let formWidth = min(190, max(150, width / 2))
                    HStack(spacing: 0) {
                        VStack(spacing: 10) {
                            brand(dot: 44, taglineWidth: (width - formWidth) * 0.72)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        VStack(alignment: .leading, spacing: 9) {
                            bar.frame(width: (formWidth - 44) * 0.45)
                            bar
                            bar
                            button
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 26)
                        .frame(width: formWidth)
                        .frame(maxHeight: .infinity)
                        .background(Self.formFill)
                        .shadow(color: .black.opacity(0.85), radius: 30, x: -30)
                    }
                } else {
                    VStack(spacing: 9) {
                        brand(dot: 34, taglineWidth: 164 * 0.72)
                        bar
                        bar
                        button
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .frame(width: 200)
                    .background(Self.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
                    .shadow(color: .black.opacity(0.7), radius: 25, y: 20)
                }
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Login preview")
    }

    @ViewBuilder
    private func brand(dot: CGFloat, taglineWidth: CGFloat) -> some View {
        if showLogo {
            Circle()
                .fill(Theme.fusion)
                .frame(width: dot, height: dot)
                .shadow(color: Theme.cyan.opacity(0.5), radius: 8, y: 6)
        }
        if showWordmark {
            Text("FUSIONHA")
                .font(.system(size: 11))
                .tracking(11 * 0.28)
                .foregroundStyle(Theme.txt)
        }
        if showTagline {
            RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.06)).frame(width: taglineWidth, height: 6)
        }
    }

    private var bar: some View {
        RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.09)).frame(height: 9)
    }

    private var button: some View {
        RoundedRectangle(cornerRadius: 5).fill(Theme.fusion).frame(height: 11).padding(.top, 2)
    }
}

/// A login-layout tile (`.lopt`): a tiny wireframe, the name and a line.
private struct LayoutTile: View {
    let key: String
    let name: String
    let desc: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                wire
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text(desc).font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .modifier(SelectedRing(selected: selected))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var wire: some View {
        ZStack {
            Theme.panel2
            if key == "split" {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack(alignment: .trailing) {
                        Color.white.opacity(0.14)
                        RoundedRectangle(cornerRadius: 2).fill(Theme.cyan.opacity(0.35))
                            .frame(width: 26, height: 5)
                            .padding(.trailing, 4)
                    }
                    .frame(width: 74 * 0.38)
                }
            } else {
                RoundedRectangle(cornerRadius: 2).fill(Theme.cyan.opacity(0.28)).frame(width: 34, height: 24)
            }
        }
        .frame(width: 74, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.14)))
    }
}

/// A background option (`.opt`): a 92pt live thumbnail of the backdrop, its
/// name and an Animated/Static tag; the chosen one gets the ring and check.
/// Only the chosen thumbnail animates (the web also animates the hovered one),
/// the rest draw one still frame, so the panel never runs nine loops.
private struct BackgroundTile: View {
    let mode: BackdropMode
    let selected: Bool
    let motionOff: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    Theme.panel
                    BackdropCanvas(mode: mode, animate: selected, motionOff: motionOff)
                }
                .frame(height: 92)
                .clipped()
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                HStack {
                    Text(mode.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    Spacer(minLength: 4)
                    Text(mode.animated ? "Animated" : "Static")
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(mode.animated ? Theme.cyan : Theme.dim)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(mode.animated ? Theme.cyan.opacity(0.4) : Theme.line))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color(hex: 0x06121A))
                        .frame(width: 20, height: 20)
                        .background(Theme.fusion, in: Circle())
                        .padding(8)
                }
            }
            .modifier(SelectedRing(selected: selected))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.name), \(mode.animated ? "animated" : "static")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// `[aria-checked='true']`: an `--i2` border plus a 3pt 22% ring; else `--line`.
private struct SelectedRing: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(selected ? Theme.cyan : Theme.line))
            .background(
                RoundedRectangle(cornerRadius: Theme.radius + 3, style: .continuous)
                    .fill(Theme.cyan.opacity(selected ? 0.22 : 0))
                    .padding(-3))
    }
}
