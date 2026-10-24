import SwiftUI
import FusionhaKit

// Small pieces that keep one element off the iPhone Duo's fold, in both
// "iPhone Duo, open" layouts. Each reads the fold in its own coordinates
// (`FoldInfo.verticalFold`), so it works at any inset, and does nothing
// without a top-to-bottom fold inside it (folded, portrait, iPad).

extension View {
    /// Leaves the fold and its gutter empty in this view (a header's hairline):
    /// what runs across is drawn either side of the gap, never in it.
    func foldGapMask() -> some View {
        modifier(FoldGapMask())
    }
}

private struct FoldGapMask: ViewModifier {
    @State private var gap: ClosedRange<CGFloat>?

    func body(content: Content) -> some View {
        content
            .mask {
                if let gap {
                    FoldGapShape(gap: gap)
                } else {
                    Rectangle()
                }
            }
            .onGeometryChange(for: ClosedRange<CGFloat>?.self) { proxy in
                LibraryFold.gap(width: Double(proxy.size.width), fold: proxy.foldRange)
                    .map { CGFloat($0.lowerBound)...CGFloat($0.upperBound) }
            } action: { gap = $0 }
    }
}

/// A rectangle with the fold's gap (a vertical band) cut out of it.
struct FoldGapShape: Shape {
    var gap: ClosedRange<CGFloat>?

    func path(in rect: CGRect) -> Path {
        guard let gap, gap.lowerBound > rect.minX, gap.upperBound < rect.maxX else { return Path(rect) }
        var path = Path()
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: gap.lowerBound - rect.minX, height: rect.height))
        path.addRect(CGRect(x: gap.upperBound, y: rect.minY, width: rect.maxX - gap.upperBound, height: rect.height))
        return path
    }
}

/// Two pieces meeting at the fold's gutter when a fold runs through the space
/// they were given (`LibraryFold.panes(piece…)`); otherwise `whole`, the
/// usual single layout. The measuring frame is always full width, so the
/// switch never feeds back into the measurement.
struct FoldSplit<Whole: View, Leading: View, Trailing: View>: View {
    let piece: LibraryFold.Piece
    var fillHeight = false
    @ViewBuilder var whole: Whole
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @State private var split: FoldColumns.Panes?

    var body: some View {
        Group {
            if let split {
                FoldPairLayout(lead: CGFloat(split.lead), gap: CGFloat(split.gap), fillHeight: fillHeight) {
                    leading
                    trailing
                }
            } else {
                whole
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: FoldColumns.Panes?.self) { proxy in
            LibraryFold.panes(piece, width: Double(proxy.size.width), fold: proxy.foldRange)
        } action: { split = $0 }
    }
}

extension GeometryProxy {
    /// The top-to-bottom fold inside this container (`FoldInfo.verticalFold`), as doubles.
    var foldRange: ClosedRange<Double>? {
        FoldInfo.verticalFold(self).map { Double($0.lowerBound)...Double($0.upperBound) }
    }

    /// A window-sized container's two pages on the open Duo (`DuoSplit`):
    /// book pose split at the fold, flat a third | two thirds. `nil` closed.
    var duoPages: SpreadGeometry.Pages? {
        guard let open = FoldInfo.openFold(self) else { return nil }
        return DuoSplit.pages(width: Double(size.width), fold: Double(open.lowerBound)...Double(open.upperBound),
                              posture: FoldInfo.isBookPose(self) ? .book : .flat)
    }
}
