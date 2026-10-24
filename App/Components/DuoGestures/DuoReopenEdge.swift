import SwiftUI
import FusionhaKit

// MARK: - Pull the last page back (gesture 4, `DuoSwipe`)
//
// On the open Duo with nothing on the right page, a swipe left from the
// content's trailing edge (just left of the system column) brings back the
// title or preview closed last on this tab, for five minutes. The strip is
// the page's 16 pt margin, so it never covers a poster, and it stands aside
// while the Library's A–Z thumb is up on that edge.

struct DuoReopenEdge: View {
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread
    @State private var armed = false
    /// Bumped when the window runs out, so the strip goes without anything else redrawing it.
    @State private var expired = 0

    private static let extent: Double = 200

    private var page: DuoGestureMemory.ClosedPage? {
        guard !model.rightPageHasItem, !model.duoGestures.edgeBusy else { return nil }
        _ = expired
        let page = model.duoGestures.reopenable(on: model.tab)
        // A preview only lives on the Spread's right page.
        if case .preview = page, !spread.isActive { return nil }
        return page
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Always there, so the expiry task runs with no strip up.
            Color.clear.frame(width: 0)
            if let page {
                Color.clear
                    .frame(width: Theme.pageGutter)
                    .contentShape(Rectangle())
                    .gesture(drag(page))
                    .padding(.top, 64)
                    .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, on in on }
                    .accessibilityHidden(true)
            }
        }
        .task(id: model.duoGestures.lastClosed) {
            guard model.duoGestures.lastClosed != nil else { return }
            try? await Task.sleep(for: .seconds(DuoSwipe.reopenWindow + 1))
            if !Task.isCancelled { expired += 1 }
        }
    }

    private func commits(_ value: DragGesture.Value) -> Bool {
        DuoSwipe.isHorizontal(dx: Double(value.translation.width), dy: Double(value.translation.height))
            && DuoSwipe.commits(translation: -Double(value.translation.width),
                                predicted: -Double(value.predictedEndTranslation.width), extent: Self.extent)
    }

    private func drag(_ page: DuoGestureMemory.ClosedPage) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { armed = commits($0) }
            .onEnded { value in
                defer { armed = false }
                guard commits(value) else { return }
                model.duoGestures.forgetClosed()
                switch page {
                case .title(let ref): model.presentedItem = ref
                case .preview(let route): model.spreadPreview = route
                }
            }
    }
}
