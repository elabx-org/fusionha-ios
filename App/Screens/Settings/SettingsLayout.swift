import SwiftUI
import FusionhaKit

// MARK: - Settings panels on wide screens (DU16, ruling S5)
//
// The web's Settings panels follow two kinds of rule. Viewport rules
// (`@media (max-width: 720px)`) flip with the desktop Settings itself, so here
// they follow `settingsDesktop`: true while Settings shows its sidebar beside
// the panel (`SettingsSplitRule`, 720 of Settings' own width, ruling S2), which
// `SettingsView` hands down as the regular size class. Container rules
// (`@container … (max-width: 560px)`, the card grids) follow the panel's own
// measured width, `paneSize`. Panels publish both through `settingsLayout()`.
//
// On iPhone Duo the detail column is about 690 wide in landscape (951 less the
// sidebar), so container thresholds above that (Custom formats 760/1100, the
// quality editor's 820) are reached on an iPad, not the Duo (recorded in the
// parity audit as S5 deviations).

private struct SettingsDesktopKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The web's desktop Settings (viewport above 720): Settings is split.
    var settingsDesktop: Bool {
        get { self[SettingsDesktopKey.self] }
        set { self[SettingsDesktopKey.self] = newValue }
    }
}

private struct SettingsLayoutReader: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            .environment(\.settingsDesktop, sizeClass == .regular)
            .publishesPaneSize()
    }
}

extension View {
    /// A Settings panel page: hands its content `settingsDesktop` and its own
    /// measured size (`paneSize`).
    func settingsLayout() -> some View {
        modifier(SettingsLayoutReader())
    }
}

/// Two config cells side by side with a hairline between (the web's provider
/// card `.body`, `1fr 1fr`), or stacked with a hairline above the second on
/// the phone.
struct SettingsCellPair<Leading: View, Trailing: View>: View {
    let sideBySide: Bool
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        if sideBySide {
            HStack(alignment: .top, spacing: 14) {
                leading.frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Theme.line).frame(width: 1)
                trailing.frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                leading
                trailing
            }
        }
    }
}
