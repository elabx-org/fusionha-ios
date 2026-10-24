import SwiftUI
import FusionhaKit

/// Where the fold runs through a container, from its reserved `.division`
/// regions, and the open Duo's posture (`DuoPosture`): an active region is
/// book pose (the fold is reserved), an inactive, zero-wide one is flat (the
/// inner display is one surface, nothing reserved; option A).
struct FoldInfo: Equatable {
    var size: CGSize = .zero
    /// The fold's x-range when it runs top to bottom in book pose (active).
    var vertical: ClosedRange<CGFloat>?
    /// The fold's y-range when it runs side to side (book, portrait).
    var horizontal: ClosedRange<CGFloat>?
    /// The fold's x-range when the Duo lies flat open (inactive, zero wide)
    /// and it runs top to bottom through the container. `nil` when `vertical`
    /// is set, or there is no fold. It says the Duo is open; nothing avoids it.
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
        #if DEBUG
        // CI's Duo harness: a fake fold, book (active) or flat (inactive).
        if DuoHarness.frame != nil, vertical == nil, let fake = DuoHarness.verticalFold(in: proxy) {
            if DuoHarness.bookPose { vertical = fake } else { flatVertical = fake }
            return
        }
        #endif
        if vertical == nil && horizontal == nil {
            flatVertical = FoldInfo.openFold(proxy)
        }
    }

    /// The open Duo's posture; `nil` without a top-to-bottom fold.
    var posture: DuoPosture? {
        if vertical != nil { return .book }
        return flatVertical != nil ? .flat : nil
    }

    /// The top-to-bottom room to keep empty: book pose only. Flat open
    /// nothing is reserved (HIG: the fold is reserved only partially open).
    var verticalGap: ClosedRange<CGFloat>? { vertical }

    /// The top-to-bottom fold to keep clear inside this container, as its
    /// x-range in the container's coordinates: only in book pose. Flat open
    /// it is `nil`, so layouts with columns lay out as usual.
    static func verticalFold(_ proxy: GeometryProxy) -> ClosedRange<CGFloat>? {
        isBookPose(proxy) ? openFold(proxy) : nil
    }

    /// Book pose: the container's active `.division` regions (no
    /// `.includeInactive`) hold a top-to-bottom fold. The posture API, never
    /// the width.
    static func isBookPose(_ proxy: GeometryProxy) -> Bool {
        #if DEBUG
        if DuoHarness.frame != nil { return DuoHarness.bookPose }
        #endif
        return divisionFrames(proxy).contains { $0.height > 0 && $0.height >= $0.width }
    }

    /// A top-to-bottom fold inside this container, active or not (flat open
    /// it is zero wide): the Duo is open in landscape, whatever the posture.
    static func openFold(_ proxy: GeometryProxy) -> ClosedRange<CGFloat>? {
        #if DEBUG
        // CI's Duo harness (`DuoHarness`): a fake fold on an iPad.
        if let fake = DuoHarness.verticalFold(in: proxy) { return fake }
        #endif
        guard #available(iOS 27.1, *) else { return nil }
        let width = proxy.size.width
        let frame = proxy.reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > 0 && $0.height >= $0.width && $0.minX > 0 && $0.maxX < width }
        return frame.map { $0.minX...max($0.minX, $0.maxX) }
    }

    /// The frames of the container's active `.division` reserved regions
    /// (the fold in book pose), in the container's own coordinates.
    static func divisionFrames(_ proxy: GeometryProxy) -> [CGRect] {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division).map(\.frame)
        }
        return []
    }

    /// Whether a fold, folded flat or not (an inactive `.division` counts), runs
    /// top to bottom through the middle of this container. Grids use it to pick
    /// an even column count, so the layout doesn't jump when the Duo half folds.
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
