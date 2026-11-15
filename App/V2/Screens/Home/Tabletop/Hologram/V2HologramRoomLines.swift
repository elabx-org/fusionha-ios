import SwiftUI
import FusionhaKit

/// The room's lines on the top half (the stage bench's `stage`,
/// "tabletop-stage", 2026-11-15): the back wall and the two side walls of
/// `TabletopRoom`, each line drawn from the viewer's eye onto the standing
/// screen, so the black room reads in line perspective behind the slab.
/// They lie wholly on the upright half and hold still for both eyes. One
/// path, 1.6 design points wide, in the floor grid's colour. Content, never
/// glass; it takes no touches.
struct V2HologramRoomLines: View {
    let rig: V2HologramRig
    let look: V2HologramLook

    static let lineWidth = 1.6

    var body: some View {
        Path { path in
            for line in TabletopRoom.lines {
                path.move(to: rig.point(line.from, on: .top))
                path.addLine(to: rig.point(line.to, on: .top))
            }
        }
        .stroke(look.grid, lineWidth: CGFloat(Self.lineWidth * rig.scale))
        .frame(width: rig.size.width, height: rig.hingeY, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
