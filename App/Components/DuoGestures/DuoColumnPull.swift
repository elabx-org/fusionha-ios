import SwiftUI
import FusionhaKit

// MARK: - Pulling the right page down (gesture 6, `DuoSwipe`)
//
// Folded, a title is a sheet and pulling it down closes it; open, it is the
// right page, so the same pull closes it there too. It rides on the page's
// own scroll: pulled past its top, the rubber band is the pull (so it never
// fights scrolling), the page shrinks back a little as it goes, and letting
// go past `DuoSwipe.pullClose` drops it away. A grabber marks it, as on the sheet.

/// The column's pull, written by the page's scroll (`duoColumnPullSource`).
@MainActor
@Observable
final class DuoColumnPull {
    /// Points pulled past the top while the finger is down; 0 otherwise.
    var overscroll: CGFloat = 0
    /// Bumped when letting go should close the page.
    var closeRequests = 0

    var progress: CGFloat { CGFloat(DuoSwipe.pullProgress(overscroll: Double(overscroll))) }
}

extension EnvironmentValues {
    /// Set by the open Duo's right page; nil in a sheet (which pulls down by itself).
    @Entry var duoColumnPull: DuoColumnPull? = nil
}

extension View {
    /// Put on the page's main vertical ScrollView: its pull past the top closes the right page.
    func duoColumnPullSource() -> some View {
        modifier(DuoColumnPullSource())
    }
}

private struct DuoColumnPullSource: ViewModifier {
    @Environment(\.duoColumnPull) private var pull
    @State private var interacting = false
    @State private var overscroll: CGFloat = 0

    func body(content: Content) -> some View {
        if let pull {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    -(geo.contentOffset.y + geo.contentInsets.top)
                } action: { _, value in
                    overscroll = max(0, value)
                    if interacting { pull.overscroll = overscroll }
                }
                .onScrollPhaseChange { old, new in
                    interacting = new == .interacting
                    guard old == .interacting, new != .interacting else { return }
                    if overscroll >= CGFloat(DuoSwipe.pullClose) { pull.closeRequests += 1 }
                    pull.overscroll = 0
                }
                .sensoryFeedback(.impact(weight: .light), trigger: pull.progress >= 1) { _, now in now }
        } else {
            content
        }
    }
}

/// The right page as it is pulled: eased back and dimmed with the pull, and
/// dropped away on closing (only a fade under Reduce Motion).
struct DuoColumnPullEffect: ViewModifier {
    let progress: CGFloat
    let drop: CGFloat
    let motion: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(motion ? 1 - progress * 0.04 : 1, anchor: .bottom)
            .offset(y: motion ? drop : 0)
            .opacity(1 - Double(progress) * 0.15 - (drop > 0 && !motion ? 1 : 0))
    }
}

/// The sheet's grabber, at the top of the right page.
struct DuoColumnGrabber: View {
    var body: some View {
        Capsule().fill(Theme.mut.opacity(0.6))
            .frame(width: 36, height: 5)
            .padding(.top, 6)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
