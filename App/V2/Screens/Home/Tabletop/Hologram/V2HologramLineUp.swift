import SwiftUI
import FusionhaKit

/// "Line it up" (the seat mock, 2026-11-15): the scene is drawn for the
/// viewer's eye height, which the phone cannot measure, so the first time
/// the hologram stands with no stored seat a glass capsule on the bottom
/// half asks for it. The slider moves the seat over 26°…68° and the scene
/// redraws as it moves (direct manipulation, also under Reduce Motion);
/// Done stores it (`V2TabletopHologram.seatKey`) and the capsule goes. The
/// Hologram button's long press brings it back (`V2HologramSwitch`). It
/// sits above the page dots (`V2HologramPage`), clear of the ring and the
/// title's row. A control, so glass; its words in the page's ink on every
/// palette.
struct V2HologramLineUp: View {
    @Binding var seat: Double
    let done: () -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 14) {
            Text("Slide until the card stands straight")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 160, alignment: .leading)
                .accessibilityHidden(true)
            Slider(value: $seat, in: TabletopProjection.seatRange)
                .tint(Theme.indigo)
                .accessibilityLabel("Seat height")
                .accessibilityValue("\(Int(seat.rounded())) degrees")
                .accessibilityHint("Slide until the card stands straight")
            Button("Done", action: done)
                .buttonStyle(.glassProminent)
                .tint(Theme.indigo)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 24)
    }
}
