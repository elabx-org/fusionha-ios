import SwiftUI
import FusionhaKit

/// Where the fold runs through a container, from its reserved `.division`
/// regions. `nil` ranges mean no fold (folded, flat open, any other device).
struct FoldInfo: Equatable {
    var size: CGSize = .zero
    /// The fold's x-range when it runs top to bottom (book, landscape).
    var vertical: ClosedRange<CGFloat>?
    /// The fold's y-range when it runs side to side (book, portrait).
    var horizontal: ClosedRange<CGFloat>?
    /// The fold's x-range when the Duo lies flat open (inactive, zero wide)
    /// and it runs top to bottom through the container. `nil` when `vertical`
    /// is set, or there is no fold.
    var flatVertical: ClosedRange<CGFloat>?

    init() {}

    /// Reads the fold from a container's geometry. The regions are empty on the
    /// first geometry pass and filled in on a later one, so this is read on
    /// every geometry change, never cached.
    init(_ proxy: GeometryProxy) {
        size = proxy.size
        for frame in FoldInfo.divisionFrames(proxy) {
            guard frame.width > 0 || frame.height > 0 else { continue }
            if frame.height >= frame.width {
                vertical = frame.minX...max(frame.minX, frame.maxX)
            } else {
                horizontal = frame.minY...max(frame.minY, frame.maxY)
            }
        }
        if vertical == nil && horizontal == nil {
            flatVertical = FoldInfo.verticalFold(proxy)
        }
    }

    /// The top-to-bottom room to keep empty: half open, the active fold as
    /// reported; flat open, the zero-wide fold with the fold gutter around it.
    var verticalGap: ClosedRange<CGFloat>? {
        if let vertical { return vertical }
        guard let x = flatVertical else { return nil }
        let gap = FoldColumns.gap(around: Double(x.lowerBound)...Double(x.upperBound))
        return CGFloat(gap.lowerBound)...CGFloat(gap.upperBound)
    }

    /// A top-to-bottom fold inside this container, active or not (flat open it
    /// is zero wide), as its x-range in the container's coordinates. Layouts
    /// with columns keep their columns off it (`FoldColumns`).
    static func verticalFold(_ proxy: GeometryProxy) -> ClosedRange<CGFloat>? {
        #if DEBUG
        // CI's Duo harness (`DuoHarness`): a fake flat fold on an iPad.
        if let fake = DuoHarness.verticalFold(in: proxy) { return fake }
        #endif
        guard #available(iOS 27.1, *) else { return nil }
        let width = proxy.size.width
        let frame = proxy.reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > 0 && $0.height >= $0.width && $0.minX > 0 && $0.maxX < width }
        return frame.map { $0.minX...max($0.minX, $0.maxX) }
    }

    /// The frames of the container's `.division` reserved regions (the fold),
    /// in the container's own coordinates.
    static func divisionFrames(_ proxy: GeometryProxy) -> [CGRect] {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division).map(\.frame)
        }
        return []
    }

    /// Whether a fold, folded flat or not (an inactive `.division` counts), runs
    /// top to bottom through the middle of this container. Grids use it to pick
    /// an even column count, so the fold falls in a gutter, never on a poster.
    static func crossesMiddle(_ proxy: GeometryProxy) -> Bool {
        let width = proxy.size.width
        guard width > 0 else { return false }
        #if DEBUG
        if let fake = DuoHarness.verticalFold(in: proxy) { return abs(fake.lowerBound - width / 2) <= 12 }
        #endif
        guard #available(iOS 27.1, *) else { return false }
        return proxy.reservedRegions(kind: .division, options: .includeInactive).contains { region in
            let frame = region.frame
            return frame.height >= frame.width && abs(frame.midX - width / 2) <= max(frame.width, 12)
        }
    }
}

