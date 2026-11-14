import SwiftUI
import FusionhaKit

/// The hologram scene's colours (the approved mock's `holo2` look with its
/// poster-colour backdrop): a dim room in the focused poster's colours, lit
/// by the title's own colour, or on a light palette a pale glass display.
/// `tint` is that colour; nothing here is a fixed indigo.
struct V2HologramLook: Equatable {
    let tint: Color
    let isLight: Bool
    /// A true-black palette (OLED, Noir): the room's own colour is black.
    var isDeep = false

    /// The room's own colour: under the poster's colours (`V2HologramRoom`),
    /// and the veil laid over them.
    var room: Color { isLight ? Theme.bg : isDeep ? .black : Color(hex: 0x0C0B11) }
    /// The veil over the poster's colours on the wall: at the top, 46% of
    /// the way down, and at the hinge. Dark, the room stays dim (the mock's
    /// 0.8 / 0.56 / 0.6). Light, it is heavier than the mock's 0.7 / 0.3 /
    /// 0.42: a near-black poster left Daylight a grey room even at 0.8 /
    /// 0.55 / 0.62 (CI, Game of Thrones).
    var wallVeil: [Double] { isLight ? [0.86, 0.64, 0.7] : [0.8, 0.56, 0.6] }
    /// The veil on the floor, past its first third (it starts at the wall's
    /// last value, so the two meet at the hinge).
    var floorVeil: Double { isLight ? 0.68 : 0.5 }
    /// The floor's plates let the room's colour through.
    var floor: Color { isLight ? Color(hex: 0xECEEF2).opacity(0.5) : Color(hex: 0x0A090E).opacity(0.46) }
    var grid: Color { isLight ? Color(hex: 0x0F1115).opacity(0.07) : .white.opacity(0.055) }
    /// The pool behind the slab: shadow in a dark room, pale in a light one.
    var shade: Color { isLight ? Color(hex: 0xFAFAFC) : Color(hex: 0x08070C) }
    var shadeCore: Double { isLight ? 0.92 : 0.86 }
    var shadeMid: Double { isLight ? 0.55 : 0.5 }
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
    /// Half the mock's plain-room halo: the shadow pool sits behind it.
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
