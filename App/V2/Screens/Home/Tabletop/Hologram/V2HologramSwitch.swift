import SwiftUI

/// The tabletop's "Hologram" switch: a round glass button with the cube
/// alone (tabletop plan, slice 6; the hinge-fix mock's `.hsw.ico`), filled
/// indigo when on. It writes the stored switch (`V2TabletopHologram.key`);
/// `V2HomeTabletop` plays the lift when it changes. 44 pt, its own target.
struct V2HologramSwitch: View {
    @AppStorage(V2TabletopHologram.key) private var stored = false
    @Environment(\.pagePalette) private var page

    private var on: Bool { V2TabletopHologram.isOn(stored: stored) }

    var body: some View {
        Button {
            stored.toggle()
        } label: {
            Image(systemName: "cube")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(on ? Color.white : (page?.ink ?? Theme.txt))
                .frame(width: 44, height: 44)
                .glassEffect(on ? .regular.tint(Theme.indigo).interactive() : .regular.interactive(), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hologram")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        .sensoryFeedback(.selection, trigger: stored)
    }
}
