import SwiftUI
import FusionhaKit

// MARK: Motion

/// True when Settings should not animate: the system Reduce Motion setting or
/// the app's own "Enable animations" switch (the web honours both).
private struct SettingsMotionOffKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var settingsMotionOff: Bool {
        get { self[SettingsMotionOffKey.self] }
        set { self[SettingsMotionOffKey.self] = newValue }
    }
}

/// Pushes a panel by slug onto the Settings stack (honours motion-off).
private struct SettingsPushKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var settingsPush: (String) -> Void {
        get { self[SettingsPushKey.self] }
        set { self[SettingsPushKey.self] = newValue }
    }
}

enum SettingsMotion {
    /// The prototype's smooth, non-elastic ease (`REVEAL_EASE`).
    static func reveal(_ duration: Double = 0.5) -> Animation {
        .timingCurve(0.52, 0.01, 0.16, 1, duration: duration)
    }

    /// The chevron / colour transition (`transition: transform 0.2s ease`).
    static let chevron = Animation.easeInOut(duration: 0.2)

    /// Runs a state change animated, or instantly when motion is off.
    static func perform(_ off: Bool, _ animation: Animation = chevron, _ change: () -> Void) {
        if off {
            var t = Transaction(animation: nil)
            t.disablesAnimations = true
            withTransaction(t, change)
        } else {
            withAnimation(animation, change)
        }
    }
}

/// The web's `<Reveal>`: content rises 16pt and fades in over 0.5s.
private struct SettingsReveal: ViewModifier {
    @Environment(\.settingsMotionOff) private var motionOff
    var delay: Double = 0
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(motionOff || shown ? 1 : 0)
            .offset(y: motionOff || shown ? 0 : 16)
            .onAppear {
                guard !motionOff, !shown else { return }
                withAnimation(SettingsMotion.reveal().delay(delay)) { shown = true }
            }
    }
}

extension View {
    func settingsReveal(delay: Double = 0) -> some View {
        modifier(SettingsReveal(delay: delay))
    }
}

// MARK: Search flash

/// The field a Settings search jumped to; the matching row flashes cyan for
/// ~2.2s (the web's `.searchFlash`), then the target clears after 2.4s.
@MainActor
@Observable
final class SettingsFlash {
    private(set) var panel: String?
    private(set) var label: String?
    private var generation = 0

    func set(panel: String, label: String?) {
        self.panel = panel
        self.label = label
        generation += 1
        let mine = generation
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if generation == mine { self.label = nil; self.panel = nil }
        }
    }

    func target(in panel: String) -> String? {
        self.panel == panel ? label : nil
    }
}

private struct FlashRowBackground: View {
    let active: Bool
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var lit = false

    var body: some View {
        Theme.card
            .overlay(Theme.i2.opacity(lit ? 0.12 : 0))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.i2.opacity(lit ? 0.7 : 0), lineWidth: 2))
            .onAppear { if active { flash() } }
            .onChange(of: active) { if active { flash() } }
    }

    private func flash() {
        lit = true
        // Hold for 55% of 2.2s, then fade out (instant under reduced motion).
        Task {
            try? await Task.sleep(for: .seconds(motionOff ? 0.6 : 1.2))
            if motionOff { lit = false } else { withAnimation(.easeOut(duration: 1.0)) { lit = false } }
        }
    }
}

private struct SettingsFieldModifier: ViewModifier {
    let label: String
    @Environment(SettingsFlash.self) private var flash
    @Environment(\.settingsPanelSlug) private var slug

    func body(content: Content) -> some View {
        content
            .id(label)
            .listRowBackground(FlashRowBackground(active: flash.target(in: slug) == label))
    }
}

private struct SettingsPanelSlugKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var settingsPanelSlug: String {
        get { self[SettingsPanelSlugKey.self] }
        set { self[SettingsPanelSlugKey.self] = newValue }
    }
}

extension View {
    /// Marks a Form row as the setting `label`, so a search hit can scroll to it
    /// and flash it. Also paints the web's card colour behind the row.
    func settingsField(_ label: String) -> some View {
        modifier(SettingsFieldModifier(label: label))
    }
}
