import SwiftUI
import FusionhaKit

// MARK: - Pulling the right page down (gesture 6, `DuoSwipe`)
//
// Folded, a title is a sheet and pulling it down closes it; open, it is the
// right page, so the same pull closes it there too. It rides on the page's
// own scroll: pulled past its top, the rubber band is the pull (so it never
// fights scrolling), the page shrinks back a little as it goes, and letting
// go past `DuoSwipe.pullClose` drops it away. A grabber marks it, as on the sheet.
//
// v2's title page at its root on the seamless flat open Duo (`sheetLike`)
// pulls like a sheet: only a drag that starts at the scroll's top counts,
// the pane follows the finger, it closes past `DuoSwipe.titlePullClose` or
// on a fling down, and springs back otherwise.

/// The column's pull, written by the page's scroll (`duoColumnPullSource`).
@MainActor
@Observable
final class DuoColumnPull {
    /// Points pulled past the top while the finger is down; 0 otherwise.
    var overscroll: CGFloat = 0
    /// Bumped when letting go should close the page.
    var closeRequests = 0
    /// v2's title at its root, flat open: the sheet-like pull (set by the column).
    var sheetLike = false
    /// v2's title with a season or episode pushed: no pull at all.
    var blocked = false

    var progress: CGFloat {
        let o = Double(overscroll)
        return CGFloat(sheetLike ? DuoSwipe.titlePullProgress(overscroll: o) : DuoSwipe.pullProgress(overscroll: o))
    }
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

/// The sheet-like pull's bookkeeping, kept out of view state so it never
/// redraws the page: where the drag started, and the pull's recent speed.
@MainActor
private final class DuoPullTracker {
    /// The scroll's distance from its top (positive = pulled past it).
    var raw: CGFloat = 0
    var startedAtTop = false
    private var last: (time: TimeInterval, value: CGFloat)?
    private var speed: Double = 0

    func begin() {
        startedAtTop = raw >= -1
        last = nil
        speed = 0
    }

    func sample(_ value: CGFloat) {
        let now = ProcessInfo.processInfo.systemUptime
        if let last, now > last.time {
            speed = Double(value - last.value) / (now - last.time)
        }
        last = (now, value)
    }

    /// The pull's growth at release, points per second; 0 once the finger rested.
    var velocity: Double {
        guard let last, ProcessInfo.processInfo.systemUptime - last.time < 0.1 else { return 0 }
        return speed
    }
}

private struct DuoColumnPullSource: ViewModifier {
    @Environment(\.duoColumnPull) private var pull
    @State private var interacting = false
    @State private var overscroll: CGFloat = 0
    @State private var tracker = DuoPullTracker()

    func body(content: Content) -> some View {
        if let pull {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    -(geo.contentOffset.y + geo.contentInsets.top)
                } action: { _, value in
                    tracker.raw = value
                    overscroll = max(0, value)
                    guard interacting, !pull.blocked else { return }
                    if pull.sheetLike {
                        guard tracker.startedAtTop else { return }
                        tracker.sample(overscroll)
                    }
                    pull.overscroll = overscroll
                }
                .onScrollPhaseChange { old, new in
                    interacting = new == .interacting
                    if new == .interacting, old != .interacting { tracker.begin() }
                    guard old == .interacting, new != .interacting else { return }
                    if pull.sheetLike {
                        release(pull)
                        return
                    }
                    if overscroll >= CGFloat(DuoSwipe.pullClose), !pull.blocked { pull.closeRequests += 1 }
                    pull.overscroll = 0
                }
                .sensoryFeedback(.impact(weight: .light), trigger: pull.progress >= 1) { _, now in now }
        } else {
            content
        }
    }

    /// The sheet-like pull let go: close (the pane keeps its place until the
    /// column drops it, `ShellDetailColumn.closeByPull`), else spring back.
    private func release(_ pull: DuoColumnPull) {
        let commits = !pull.blocked && tracker.startedAtTop
            && DuoSwipe.titlePullCommits(overscroll: Double(overscroll), velocity: tracker.velocity)
        tracker.startedAtTop = false
        if commits {
            pull.closeRequests += 1
        } else if pull.overscroll != 0 {
            withAnimation(.spring(duration: 0.3, bounce: 0.15)) { pull.overscroll = 0 }
        }
    }
}

/// The right page as it is pulled: eased back and dimmed with the pull, and
/// dropped away on closing (only a fade under Reduce Motion). The sheet-like
/// pull also follows the finger and shrinks from its top, as a sheet does.
struct DuoColumnPullEffect: ViewModifier {
    let progress: CGFloat
    let drop: CGFloat
    let motion: Bool
    /// The sheet-like pull's travel past the top (0 for v1's pull).
    var follow: CGFloat = 0
    var sheetLike = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(motion ? 1 - progress * 0.04 : 1, anchor: sheetLike ? .top : .bottom)
            .offset(y: motion ? drop + follow * 0.6 : 0)
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
