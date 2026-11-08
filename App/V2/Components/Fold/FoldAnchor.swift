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

    func record(_ id: AnyHashable) {
        log.record(id, at: ProcessInfo.processInfo.systemUptime)
    }
}

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
            content.onGeometryChange(for: Bool.self) { geo in
                guard let visible = geo.bounds(of: .scrollView) else { return false }
                // The eye's line: under the bars, a fifth of the way down at most.
                let line = visible.minY + min(120, visible.height * 0.2)
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
            .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { height = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { new in
                let old = width
                width = new
                guard active, old > 0, abs(new - old) > 1,
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

    /// The row goes back under the eye line, not to the very top: with the
    /// top at the line, the next fold would find the row below it.
    private func scroll(to anchor: AnyHashable) {
        guard let id = anchor.base as? any Hashable else { return }
        let line = height > 0 ? min(120, height * 0.2) / height : 0.2
        proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: line))
    }
}
