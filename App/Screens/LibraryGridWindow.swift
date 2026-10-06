import SwiftUI
import FusionhaKit

/// The A–Z grid's window (the web's `VirtualAlphaGrid`): every row's height and
/// offset are known up front, the grid is a spacer of the true library height,
/// and only the rows in the viewport (+ overscan) are rendered. A jump first
/// *pins* the target window so its rows (card frames, titles, version chips)
/// exist before the scroll lands on them: a jump never shows a blank frame.
@MainActor
@Observable
final class LibraryGridWindow {
    /// Rows rendered beyond each viewport edge so a fast fling never shows blank.
    static let overscan = 500.0

    struct Entry: Equatable {
        let id: String
        let slots: Int
    }

    private(set) var layout = RowWindowLayout()
    private(set) var visible: Range<Int> = 0..<0
    /// The window a jump is heading to, kept rendered until the scroll lands.
    private(set) var pinned: Range<Int>?

    @ObservationIgnored private var entries: [Entry] = []
    @ObservationIgnored private var heights = GridRowHeights()
    @ObservationIgnored private var pinTarget: Int?
    /// The scroll view's visible rect in grid space.
    @ObservationIgnored private var viewTop = 0.0
    @ObservationIgnored private var viewHeight = 1000.0

    /// The row indices to render, in order.
    var rendered: [Int] {
        guard let pinned else { return Array(visible) }
        if pinned.overlaps(visible) || pinned.upperBound == visible.lowerBound || visible.upperBound == pinned.lowerBound {
            return Array(min(pinned.lowerBound, visible.lowerBound)..<max(pinned.upperBound, visible.upperBound))
        }
        return pinned.lowerBound < visible.lowerBound ? Array(pinned) + Array(visible) : Array(visible) + Array(pinned)
    }

    /// New rows or a new card width: relayout.
    func configure(entries: [Entry], cardWidth: CGFloat) {
        heights.reset(cardWidth: Double(cardWidth))
        self.entries = entries
        relayout()
    }

    /// A rendered row's natural height; a taller one than expected relayouts.
    func observe(slots: Int, height: CGFloat) {
        if heights.observe(slots: slots, height: Double(height)) { relayout() }
    }

    func height(of index: Int) -> CGFloat {
        layout.rows.indices.contains(index) ? CGFloat(layout.rows[index].height) : 0
    }

    func offset(of index: Int) -> CGFloat {
        layout.rows.indices.contains(index) ? CGFloat(layout.rows[index].y) : 0
    }

    /// The scroll view's visible rect, in the grid's own coordinates.
    func track(_ rect: CGRect) {
        guard rect.height > 0 else { return }
        viewTop = Double(rect.minY)
        viewHeight = Double(rect.height)
        updateVisible()
    }

    /// Renders the window that row `id` at the top of the screen shows. Returns
    /// false when the row is not in the grid.
    @discardableResult
    func pin(_ id: String) -> Bool {
        guard let index = layout.index(of: id) else { return false }
        let range = layout.range(landingAt: index, viewport: viewHeight, overscan: Self.overscan)
        pinTarget = index
        if pinned != range { pinned = range }
        return true
    }

    private func relayout() {
        let next = RowWindowLayout(entries.map { (id: $0.id, height: heights.height(slots: $0.slots)) })
        if next != layout { layout = next }
        if let target = pinTarget, target >= layout.rows.count { pinTarget = nil; pinned = nil }
        updateVisible()
    }

    private func updateVisible() {
        let next = layout.range(top: viewTop, bottom: viewTop + viewHeight, overscan: Self.overscan)
        if next != visible { visible = next }
        // Landed: the target is on screen, so the visible window covers it.
        if let target = pinTarget,
           layout.range(top: viewTop, bottom: viewTop + viewHeight, overscan: 0).contains(target) {
            pinTarget = nil
            pinned = nil
        }
    }

    #if DEBUG
    /// CI sweep screenshots: the window's state, drawn over the page.
    var debugLine: String {
        let pin = pinned.map { "\($0.lowerBound)..<\($0.upperBound)" } ?? "-"
        return "rows \(layout.rows.count) vis \(visible.lowerBound)..<\(visible.upperBound) pin \(pin) "
            + "top \(Int(viewTop)) h \(Int(viewHeight)) total \(Int(layout.totalHeight))"
    }
    #endif
}
