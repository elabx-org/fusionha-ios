import SwiftUI
import FusionhaKit

/// The hologram scene's colours (the approved mock's `holo2` look): a dark
/// room lit by the focused title's own colour, or on a light palette a pale
/// glass display. `tint` is that colour; nothing here is a fixed indigo.
struct V2HologramLook: Equatable {
    let tint: Color
    let isLight: Bool

    /// The room behind the scene (the wall and under the floor).
    var room: Color { isLight ? Theme.bg : Color(hex: 0x0C0B11) }
    var floor: Color { isLight ? Color(hex: 0xECEEF2) : Color(hex: 0x0A090E) }
    var grid: Color { isLight ? Color(hex: 0x0F1115).opacity(0.07) : .white.opacity(0.055) }
    /// The emitter, the track and the posters' lit edge.
    var ring: Color { isLight ? tint.mix(with: Color(hex: 0x14161D), by: 0.18) : tint.mix(with: .white, by: 0.38) }
    /// The emitter's core.
    var core: Color { isLight ? tint.mix(with: .white, by: 0.3) : .white }
    /// The glass slices behind the focused poster.
    var slice: Color { tint.mix(with: .white, by: isLight ? 0.3 : 0.45) }
    var sliceOpacity: Double { isLight ? 0.6 : 0.72 }
    /// Light adds on a dark room; on a light one it is laid over.
    var lightBlend: BlendMode { isLight ? .normal : .screen }
    var wallGlow: Double { isLight ? 0.24 : 0.34 }
    /// The pool of light under the ring, and behind the hinge.
    var floorGlow: Double { 0.44 }
    var padGlow: Double { isLight ? 0.26 : 0.4 }
    var spillGlow: Double { isLight ? 0.22 : 0.36 }
    var haloGlow: Double { isLight ? 0.34 : 0.58 }
    /// The reflection goes quiet on a light floor.
    var reflection: Double { isLight ? 0.67 : 1 }

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
