import SwiftUI

/// Applies the device's palette at the root: the forced colour scheme (none
/// for Automatic), the control tint, and the system's scheme fed back to
/// `PaletteStore` so Automatic can pick Daylight or the dark palette.
struct PaletteRoot: ViewModifier {
    let signedOut: Bool
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let store = PaletteStore.shared
        content
            .tint(Theme.indigo)
            .preferredColorScheme(store.screenScheme)
            .onChange(of: scheme, initial: true) { store.systemScheme(scheme) }
            .onChange(of: signedOut, initial: true) { store.setSignInShowing(signedOut) }
    }
}

extension View {
    func paletteRoot(signedOut: Bool) -> some View { modifier(PaletteRoot(signedOut: signedOut)) }
}
