import SwiftUI

/// v2's W1 card (owner-approved 2026-11-05, mock cards-w.js): a module of
/// frosted system material over the page ground, the way widgets and
/// Weather draw it. No stroke, a 0.5pt light edge along the top, one soft
/// shadow, 22pt corners. System material, not Liquid Glass (no refraction or
/// specular): glass stays on the controls.
struct ModuleSurface: View {
    var radius: CGFloat = ModuleMetrics.radius
    @Environment(\.pagePalette) private var page
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let light = page?.isLight ?? Theme.isLight
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // The material takes the page's tone, not the device's, so a
        // previewed palette draws the card that palette really shows.
        shape
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, light ? .light : .dark)
            .overlay(shape.fill(ModuleMetrics.wash(light: light)))
            // The top light edge as a gradient stroke, not a masked one
            // (a mask is an offscreen pass per card while a list scrolls).
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [ModuleMetrics.edge(light: light), .clear], startPoint: .top,
                               endPoint: .init(x: 0.5, y: 0.08)),
                lineWidth: EditionChip.hairline(displayScale)))
            .background { ModuleShadow(radius: radius, light: light) }
    }
}

/// The W1 numbers (cards-w.js `--wm*`).
enum ModuleMetrics {
    static let radius: CGFloat = 22
    /// A plain card's inset; a captioned module uses `moduleInsets`.
    static let inset: CGFloat = 16
    /// The caption sits inside the module: 13 on top, 16 at the sides, 4 at
    /// the foot (its rows carry 12 each of their own).
    static let moduleInsets = EdgeInsets(top: 13, leading: 16, bottom: 4, trailing: 16)
    static let rowPadding: CGFloat = 12

    /// The tint over the material: rgba(30,30,38,.40) dark, white .58 light.
    static func wash(light: Bool) -> Color {
        light ? .white.opacity(0.58) : Color(red: 30 / 255, green: 30 / 255, blue: 38 / 255).opacity(0.40)
    }

    /// The top light edge: white .16 dark, .95 light.
    static func edge(light: Bool) -> Color {
        .white.opacity(light ? 0.95 : 0.16)
    }

    /// The hairline between rows: white .10 dark, rgba(20,22,30,.09) light.
    static func hairline(light: Bool) -> Color {
        light ? Color(red: 20 / 255, green: 22 / 255, blue: 30 / 255).opacity(0.09) : .white.opacity(0.10)
    }
}

extension View {
    /// The W1 frosted card behind this content, inset by `padding` (0 when
    /// the content pads itself). Content stays solid; only the surface is
    /// material.
    func v2CardStyle(padding: CGFloat = ModuleMetrics.inset, radius: CGFloat = ModuleMetrics.radius) -> some View {
        self
            .padding(padding)
            .background { ModuleSurface(radius: radius) }
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
