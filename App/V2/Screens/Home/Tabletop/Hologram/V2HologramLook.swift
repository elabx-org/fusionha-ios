import SwiftUI
import FusionhaKit

/// The hologram scene's colours (the stage bench, "tabletop-stage",
/// 2026-11-15): a black room drawn in lines, lit by the title's own colour,
/// or on a light palette the page's pale ground with near-black lines.
/// `tint` is that colour; nothing here is a fixed indigo.
struct V2HologramLook: Equatable {
    let tint: Color
    let isLight: Bool

    /// The room: wall and floor. Pure black on every dark palette; the
    /// page's pale ground on a light one.
    var room: Color { isLight ? Theme.bg : .black }
    /// The floor's plates are the room's own colour: only their lines show.
    var floor: Color { room }
    /// The floor grid and the room's lines (the mock's `--gridc`): dark, the
    /// title's light 62% toward white at 25% (CSS `color-mix` with alpha:
    /// 0.715 alpha, 13% white); light, near black at 0.3.
    var grid: Color { isLight ? Color(hex: 0x14161D).opacity(0.3) : tint.mix(with: .white, by: 0.13).opacity(0.715) }
    /// The emitter, the track and the posters' lit edge.
    var ring: Color { isLight ? tint.mix(with: Color(hex: 0x14161D), by: 0.18) : tint.mix(with: .white, by: 0.38) }
    /// The dial's fixed marker at the ring's far side (the label colour).
    var marker: Color { isLight ? Color(hex: 0x14161D) : .white }
    /// The emitter's core.
    var core: Color { isLight ? tint.mix(with: .white, by: 0.3) : .white }
    /// The glass slices behind the focused poster.
    var slice: Color { tint.mix(with: .white, by: isLight ? 0.3 : 0.45) }
    var sliceOpacity: Double { isLight ? 0.6 : 0.72 }
    /// Light adds on a dark room; on a light one it is laid over.
    var lightBlend: BlendMode { isLight ? .normal : .screen }
    /// The pool of light under the ring, and behind the hinge.
    var floorGlow: Double { 0.44 }
    var padGlow: Double { isLight ? 0.26 : 0.4 }
    /// Half the mock's plain-room halo.
    var haloGlow: Double { isLight ? 0.17 : 0.29 }
    /// The reflection goes quiet on a light floor; on a dark one it is
    /// light on the floor (it adds), so a dark poster leaves no slab of black.
    var reflection: Double { isLight ? 0.45 : 1 }

    /// The light for a title whose art's dominant colours are `dominant`
    /// (`ArtPaletteExtractor`, the colours Home's ground is built from): the
    /// lead colour, kept mid-light so it reads as light on either room. Grey
    /// until the colours are in, and on palettes without a hue.
    static func tint(_ dominant: [HSLColor]?, mono: Bool) -> Color {
        guard let lead = dominant?.first else { return Color(hsl: HSLColor(h: 0, s: 0, l: 0.56)) }
        return Color(hsl: HSLColor(h: lead.h,
                                   s: mono ? 0 : min(0.75, max(lead.s, 0.25)),
                                   l: min(0.58, max(lead.l, 0.42))))
    }
}
