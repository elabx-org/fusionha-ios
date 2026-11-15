import SwiftUI

/// The tabletop's "Hologram" switch: a round glass button with the cube
/// alone (tabletop plan, slice 6; the hinge-fix mock's `.hsw.ico`), filled
/// indigo when on. It writes the stored switch (`V2TabletopHologram.key`);
/// `V2HomeTabletop` plays the lift when it changes. 44 pt, its own target.
/// A long press offers "Adjust for my seat", which turns the hologram on
/// and shows the line-up control again (`V2HologramLineUp`).
struct V2HologramSwitch: View {
    @AppStorage(V2TabletopHologram.key) private var stored = false
    @Environment(\.pagePalette) private var page
    @Environment(\.adjustTabletopSeat) private var adjustSeat

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
        .contextMenu {
            Button("Adjust for my seat", systemImage: "slider.horizontal.3") { adjustSeat() }
        }
        .accessibilityLabel("Hologram")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        .sensoryFeedback(.selection, trigger: stored)
    }
}

extension EnvironmentValues {
    /// Shows the hologram's line-up control again (`V2HomeTabletop` sets it).
    @Entry var adjustTabletopSeat: @MainActor () -> Void = {}
}
