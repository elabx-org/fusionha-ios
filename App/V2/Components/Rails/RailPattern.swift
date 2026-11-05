import SwiftUI
import FusionhaKit

/// How a rail draws downloading and held when `BadgeInk.patterned` is on
/// (OLED, Noir, Monochrome): their inks sit on the on-disk grey there, so
/// downloading is the track with 1pt accent hatching at a 3pt pitch, and held
/// the track with a 1pt held outline.
enum RailPattern {
    static let pitch: CGFloat = 3

    /// Diagonal hatch lines covering `rect` (clip to the stretch).
    static func hatch(in rect: CGRect) -> Path {
        MonoPattern.diag.marks(in: CGSize(width: rect.maxX, height: rect.maxY), cell: pitch).stroke
    }
}

/// The hatch as a shape, for the episode ticks.
struct RailHatch: Shape {
    func path(in rect: CGRect) -> Path {
        RailPattern.hatch(in: rect)
    }
}
