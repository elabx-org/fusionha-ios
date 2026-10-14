import SwiftUI

/// Settings › Appearance › Theme: this iPhone's colours. Dark, Light or
/// Automatic, and which dark and light palette. Stored on the device (and
/// shared with the widgets), not on the server; it applies at once and keeps
/// your place.
struct AppPaletteSection: View {
    @Environment(\.settingsMotionOff) private var motionOff

    var body: some View {
        let store = PaletteStore.shared
        SettingsSection("App colours", footer: "Only this iPhone. Automatic follows the system: your light palette by day, your dark one at night.") {
            Picker("Appearance", selection: Binding(get: { store.appearance }, set: { store.select(appearance: $0) })) {
                ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .settingsField("App colours")
        SettingsSection("Dark palettes") {
            ForEach(AppPalette.dark) { palette in
                row(palette, selected: store.darkPalette == palette, showing: store.active == palette) { store.select(palette) }
            }
        }
        SettingsSection("Light palettes") {
            ForEach(AppPalette.light) { palette in
                row(palette, selected: store.lightPalette == palette, showing: store.active == palette) { store.select(palette) }
            }
        }
        .sensoryFeedback(.selection, trigger: store.active)
    }

    private func row(_ palette: AppPalette, selected: Bool, showing: Bool, pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            HStack(spacing: 12) {
                PaletteSwatch(tokens: palette.tokens)
                VStack(alignment: .leading, spacing: 2) {
                    Text(palette.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    Text(palette.blurb).font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: showing ? "checkmark.circle.fill" : "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(showing ? Theme.i2 : Theme.mut)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .animation(motionOff ? nil : .easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(showing ? "Showing now" : selected ? "Selected" : "")
    }
}

/// A palette in miniature: its ground, text lines, a panel and the primary.
struct PaletteSwatch: View {
    let tokens: PaletteTokens

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: tokens.bg))
            VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(Color(hex: tokens.txt)).frame(width: 16, height: 3)
                Capsule().fill(Color(hex: tokens.mut)).frame(width: 11, height: 3)
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: tokens.panel)).frame(width: 24, height: 8)
            }
            .padding(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Circle().fill(tokens.primaryGradient).frame(width: 11, height: 11).padding(4)
        }
        .frame(width: 40, height: 40)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
        .accessibilityHidden(true)
    }
}
