import SwiftUI
import FusionhaKit

// A list keeps the row at its top across a fold (`FoldAnchorLog`): the
// rows marked `.foldAnchor(id)` say when they come to the top, and the
// scroll view (`.keepsFoldAnchor(_:proxy:)`) scrolls that row back to the
// top once a resize has re-flowed it. A row "at the top" is the one under a
// line just below the bars, so the anchor is what the eye was on.

extension EnvironmentValues {
    @Entry var foldAnchor: FoldAnchorTracker?
}

/// The list's anchor log, one per list (`@State`).
@MainActor
final class FoldAnchorTracker {
    var log = FoldAnchorLog<AnyHashable>()
    /// Each marked row's height, so a restore can place the row's top.
    var heights: [AnyHashable: CGFloat] = [:]
    /// The list is at its very top: a resize keeps it there, whatever row
    /// sits under the eye line (owner's review, 2026-11-18: the open Duo's
    /// list column came up on "Movies", its heading under the bar's pill).
    var atTop = true
    /// The bars over the list (its content insets): `scrollTo` places rows
    /// in the area between them, the eye line is measured from the top.
    var insetTop: CGFloat = 0
    var insetBottom: CGFloat = 0

    /// The eye's line, from the scroll view's top: below the bars, a fifth
    /// of the way down (120 pt at most) or 40 pt under the bar if lower.
    func line(height: CGFloat) -> CGFloat {
        max(min(120, height * 0.2), insetTop + 40)
    }

    /// How far into the row the line falls once a row is restored.
    static let restoreDepth: CGFloat = 16

    func record(_ id: AnyHashable) {
        log.record(id, at: ProcessInfo.processInfo.systemUptime)
    }
}

/// The 1 pt mark at the top of a `foldRow`.
struct FoldRowTop: Hashable { let id: AnyHashable }

/// The id of a list's header row: an anchor on it keeps a list that was at
/// its top at its top.
enum FoldAnchorTop: Hashable { case header }

extension View {
    /// Marks a row the list may keep at its top across a fold. The row must
    /// also carry `.id(id)` (the scroll view scrolls to it).
    func foldAnchor<ID: Hashable>(_ id: ID) -> some View {
        modifier(FoldAnchorRow(id: AnyHashable(id)))
    }

    /// `.id(id)` and `.foldAnchor(id)` together: a list row kept across a fold.
    func foldRow<ID: Hashable>(_ id: ID) -> some View {
        self.id(id).foldAnchor(id)
            // A point at the row's top: a row taller than the list scrolls
            // back by it (`FoldAnchorScroll.scroll(to:)`).
            .background(alignment: .top) {
                Color.clear.frame(height: 1).id(FoldRowTop(id: AnyHashable(id)))
            }
    }

    /// The scroll view keeps its top row across a resize (inside a
    /// `ScrollViewReader`); `active` false while a drag resizes it.
    func keepsFoldAnchor(_ tracker: FoldAnchorTracker, proxy: ScrollViewProxy, active: Bool = true) -> some View {
        modifier(FoldAnchorScroll(tracker: tracker, proxy: proxy, active: active))
    }
}

private struct FoldAnchorRow: ViewModifier {
    @Environment(\.foldAnchor) private var tracker
    let id: AnyHashable

    @ViewBuilder
    func body(content: Content) -> some View {
        if let tracker {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tracker.heights[id] = $0 }
                .onGeometryChange(for: Bool.self) { geo in
                guard let visible = geo.bounds(of: .scrollView) else { return false }
                let line = visible.minY + tracker.line(height: visible.height)
                return line >= 0 && line < geo.size.height
            } action: { atTop in
                if atTop { tracker.record(id) }
            }
        } else {
            content
        }
    }
}

private struct FoldAnchorScroll: ViewModifier {
    let tracker: FoldAnchorTracker
    let proxy: ScrollViewProxy
    let active: Bool
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .environment(\.foldAnchor, tracker)
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top <= 2 } action: {
                tracker.atTop = $1
            }
            .onScrollGeometryChange(for: EdgeInsets.self) { $0.contentInsets } action: {
                tracker.insetTop = $1.top
                tracker.insetBottom = $1.bottom
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { height = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { new in
                let old = width
                width = new
                guard active, old > 0, abs(new - old) > 1, !tracker.atTop,
                      let anchor = tracker.log.anchor(before: ProcessInfo.processInfo.systemUptime) else { return }
                Task { @MainActor in
                    // Once the re-flowed rows are laid out.
                    try? await Task.sleep(for: .milliseconds(60))
                    var instant = Transaction()
                    instant.disablesAnimations = true
                    withTransaction(instant) { scroll(to: anchor) }
                    tracker.log.settle(anchor, at: ProcessInfo.processInfo.systemUptime)
                }
            }
    }

    /// The row's top goes back just above the eye line (`restoreDepth`),
    /// below the bars: the next fold still finds the row there. `scrollTo`
    /// works in the area between the bars (height H) and lines up the same
    /// unit point of the row and that area, so a row of height h has its top
    /// at y·(H − h): y = top / (H − h). A row too tall for that (Home's
    /// shelves, the folded timeline) would need a negative y, which
    /// `scrollTo` doesn't honour: its 1 pt top mark (`FoldRowTop`) goes there.
    /// (A plain 0.2 put a tall row's middle at the line and its heading under
    /// the bar; measuring the line from the screen's top and the restore from
    /// the bar's bottom drifted a section up on every fold.)
    private func scroll(to anchor: AnyHashable) {
        let visible = height - tracker.insetTop - tracker.insetBottom
        guard visible > 0, let id = anchor.base as? any Hashable else { return }
        let top = max(0, tracker.line(height: height) - FoldAnchorTracker.restoreDepth - tracker.insetTop)
        let span = visible - (tracker.heights[anchor] ?? 0)
        if span > top + 1 {
            proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: top / span))
        } else {
            proxy.scrollTo(FoldRowTop(id: anchor), anchor: UnitPoint(x: 0.5, y: top / visible))
        }
    }
}
