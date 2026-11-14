import SwiftUI

/// The tabletop's "Hologram" switch: a glass capsule on the bottom half
/// (the approved mock's `.hsw`), indigo when on. It writes the stored switch
/// (`V2TabletopHologram.key`); `V2HomeTabletop` plays the lift when it
/// changes. 36 pt tall with a 44 pt target.
struct V2HologramSwitch: View {
    @AppStorage(V2TabletopHologram.key) private var stored = false
    @Environment(\.pagePalette) private var page

    private var on: Bool { V2TabletopHologram.isOn(stored: stored) }

    var body: some View {
        Button {
            stored.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cube")
                    .font(.system(size: 14, weight: .semibold))
                Text("Hologram")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(on ? Color.white : (page?.ink ?? Theme.txt))
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .frame(height: 36)
            .glassEffect(on ? .regular.tint(Theme.indigo).interactive() : .regular.interactive(), in: Capsule())
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hologram")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        .sensoryFeedback(.selection, trigger: stored)
    }
}
