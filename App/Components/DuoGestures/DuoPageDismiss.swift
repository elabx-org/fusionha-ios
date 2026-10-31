import SwiftUI
import FusionhaKit

// MARK: - Closing a page over the window (gesture 5, `DuoSwipe`)
//
// On the open Duo, Add, Request, Manual Import, trailers and collections fill
// a page (`duoPageSheet`) instead of a sheet, so they lost the sheet's
// pull-down; this gives it back: pull down from the top of the page (its bar
// zone, marked by a grabber), the page follows and the dim lightens. A page
// can say it's busy (nothing closes it) or holds unsaved choices (closing
// asks first); a tap on the dim side asks the same way.

/// What closing the page does right now; the page's content sets it.
enum DuoPageDismissPolicy: Equatable {
    case allowed
    /// Working: neither the pull nor the dim closes it (the sheet's
    /// `interactiveDismissDisabled`).
    case busy
    /// Unsaved choices: ask with this question first.
    case confirm(String)
}

@MainActor
@Observable
final class DuoPageDismissGuard {
    var policy: DuoPageDismissPolicy = .allowed
}

extension View {
    /// This page's close policy while it is on a page of the open Duo (no-op in a sheet).
    func duoPageDismiss(_ policy: DuoPageDismissPolicy) -> some View {
        modifier(DuoPageDismissWriter(policy: policy))
    }
}

private struct DuoPageDismissWriter: ViewModifier {
    @Environment(DuoPageDismissGuard.self) private var dismissGuard: DuoPageDismissGuard?
    let policy: DuoPageDismissPolicy

    func body(content: Content) -> some View {
        content
            .onChange(of: policy, initial: true) { dismissGuard?.policy = policy }
            .onDisappear { dismissGuard?.policy = .allowed }
    }
}

/// The pull-down on a page: drives `pull` and asks the cover to close.
struct DuoPagePull: ViewModifier {
    @Binding var pull: CGFloat
    let height: CGFloat
    let attemptClose: () -> Void
    let busy: Bool
    /// Keeps the grabber off the fold when the page spans both halves.
    var grabberOffset: CGFloat = 0
    @State private var armed = false
    @State private var tracking = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                Capsule().fill(Theme.mut.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 6)
                    .offset(x: grabberOffset, y: pull)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .simultaneousGesture(drag)
            .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, on in on }
    }

    private func commits(_ value: DragGesture.Value) -> Bool {
        !busy && DuoSwipe.commits(translation: Double(value.translation.height),
                                  predicted: Double(value.predictedEndTranslation.height),
                                  extent: Double(height), share: 0.25)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                if !tracking {
                    let dy = value.translation.height, dx = value.translation.width
                    guard Double(value.startLocation.y) <= DuoSwipe.pullZone, dy > 0, dy > abs(dx) * 1.2 else { return }
                    tracking = true
                }
                let dy = max(0, value.translation.height)
                pull = busy ? dy * 0.15 : dy
                armed = commits(value)
            }
            .onEnded { value in
                defer { tracking = false; armed = false }
                guard tracking else { return }
                if commits(value) {
                    attemptClose()
                } else {
                    withAnimation(.spring(duration: 0.3, bounce: 0)) { pull = 0 }
                }
            }
    }
}
