import Foundation

/// One straight line of the scene, from `from` to `to`.
public struct TabletopSegment: Equatable, Sendable {
    public let from: TabletopVec
    public let to: TabletopVec

    public init(_ from: TabletopVec, _ to: TabletopVec) {
        self.from = from
        self.to = to
    }
}

/// The hologram's room (the stage bench's `stage`, "tabletop-stage",
/// 2026-11-15): a black room drawn in line perspective behind the hinge, so
/// the depth comes from lines that lie wholly on the standing half and hold
/// still for both eyes. A back wall `depth` behind the hinge and `height`
/// tall, as wide as the display, with a vertical every grid column and a
/// horizontal every `rowHeight`; two side walls at the display's edges with
/// the same horizontals from the back wall to the hinge and a vertical every
/// `bay`. Pure numbers in the rig's coordinates; the app draws them from the
/// eye on the standing half (`TabletopProjection.onScreen`).
public enum TabletopRoom {
    public static let depth = 300.0
    public static let height = 330.0
    /// The side walls: at the display's edges.
    public static let halfWidth = TabletopProjection.designWidth / 2
    /// The back wall's columns: the floor grid's twelve.
    public static let columns = 12
    public static let rows = 6
    public static var rowHeight: Double { height / Double(rows) }
    /// The side walls' verticals: every `bay` from the back wall to the hinge.
    public static let bay = 100.0

    /// The back wall's verticals, left to right (13).
    public static var backVerticals: [TabletopSegment] {
        (0...columns).map { i in
            let x = -halfWidth + Double(i) * 2 * halfWidth / Double(columns)
            return TabletopSegment(TabletopVec(x, 0, -depth), TabletopVec(x, -height, -depth))
        }
    }

    /// The back wall's horizontals, bottom to top (6; the floor's back edge
    /// is the grid's).
    public static var backHorizontals: [TabletopSegment] {
        (1...rows).map { i in
            let y = -Double(i) * rowHeight
            return TabletopSegment(TabletopVec(-halfWidth, y, -depth), TabletopVec(halfWidth, y, -depth))
        }
    }

    /// The side walls' horizontals, from the back wall to the hinge: left, then right (12).
    public static var sideHorizontals: [TabletopSegment] {
        [-halfWidth, halfWidth].flatMap { x in
            (1...rows).map { i in
                let y = -Double(i) * rowHeight
                return TabletopSegment(TabletopVec(x, y, -depth), TabletopVec(x, y, 0))
            }
        }
    }

    /// The side walls' verticals at z −300, −200, −100 and 0: left, then right (8).
    public static var sideVerticals: [TabletopSegment] {
        let count = Int((depth / bay).rounded())
        return [-halfWidth, halfWidth].flatMap { x in
            (0...count).map { i in
                let z = -depth + Double(i) * bay
                return TabletopSegment(TabletopVec(x, 0, z), TabletopVec(x, -height, z))
            }
        }
    }

    /// Every line of the room (39).
    public static var lines: [TabletopSegment] {
        backVerticals + backHorizontals + sideHorizontals + sideVerticals
    }
}
