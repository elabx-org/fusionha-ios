import SwiftUI
import FusionhaKit

// MARK: - Add title on the open iPhone Duo (Duo Add mock, part A)
//
// With the fold through the sheet (`duoPageSheet(.twoPages)`), Add follows
// the Library's rule (owner, 2026-11-09): nothing picked, Find spans the
// whole width (kinds, source, search, the results or trending grid) and the
// column's Close shuts Add. Tapping a title slides its setup in from the
// trailing edge, Find narrowing to the lead pane; the column's Close then
// closes the setup back to full-width Find. Picking another title over a
// setup with choices asks first. Folded, in portrait and on a phone it stays
// one flow: search, then push.

extension AddTitleSheet {
    var setupOpen: Bool { flow != nil || requestPick != nil }

    func spread(_ panes: FoldColumns.Panes) -> some View {
        NavigationStack(path: $path) {
            HStack(spacing: 0) {
                findPage()
                    .frame(width: setupOpen ? CGFloat(panes.lead) : nil)
                    .frame(maxWidth: setupOpen ? nil : .infinity)
                    .overlay(alignment: .trailing) {
                        // Flat: the pages meet at the hinge line, nothing on it.
                        if setupOpen && panes.gap == 0 {
                            Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea()
                        }
                    }
                if setupOpen {
                    // Book: the fold's gutter, holding nothing.
                    Color.clear.frame(width: CGFloat(panes.gap))
                    rightPage
                        .frame(maxWidth: .infinity)
                        .transition(motion ? .move(edge: .trailing) : .opacity)
                }
            }
            .toolbar {
                if !setupOpen {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCancelButton(title: "Close") { dismiss() }
                    }
                }
            }
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: AddDetailsRoute.self) { details in
                previewPage(details.route)
                    .modifier(ZoomTransition(id: details.zoomId, namespace: zoomSpace))
            }
            .navigationDestination(for: PreviewRoute.self) { route in
                previewPage(route)
            }
        }
        .confirmationDialog("Discard this title's setup?", isPresented: discardAsk, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                if let pendingPick { startFlow(pendingPick) } else if pendingClose { clearSetup() }
                pendingPick = nil
                pendingClose = false
            }
            Button("Keep editing", role: .cancel) {
                pendingPick = nil
                pendingClose = false
            }
        }
    }

    /// The right page: the pick's setup or a requester's request.
    @ViewBuilder
    var rightPage: some View {
        if let flow {
            // Search stays on the left page: no "Search again" here. Close
            // shuts the setup, as the column's Close shuts a Library title.
            AddConfigView(flow: flow, onSearchAgain: nil, onViewDetails: viewDetailsAction(flow),
                          onClose: closeSetup, onAdded: { added($0, flow: flow) },
                          zoom: flow.pick.tmdbResult == nil ? nil : (id: heroZoomId(flow), namespace: zoomSpace))
                .id(flow.pick.key)
        } else if let requestPick {
            RequestModal(pick: requestPick, formSized: false) { Task { await model.refreshShell() } }
                .id(requestPick.id)
        }
    }

    /// A pick from Find. On the spread, a pick over a setup with choices asks
    /// first.
    func choose(_ pick: AddPick) {
        guard foldPanes != nil, initialPick == nil, let flow else { return startFlow(pick) }
        if flow.pick.key == pick.key { return }
        if flow.touched {
            pendingPick = pick
        } else {
            startFlow(pick)
        }
    }

    /// The setup's Close: back to full-width Find, asking first over choices.
    func closeSetup() {
        if flow?.touched == true {
            pendingClose = true
        } else {
            clearSetup()
        }
    }

    func clearSetup() {
        withAnimation(motion ? .snappy(duration: 0.3) : nil) {
            flow = nil
            requestPick = nil
            path = NavigationPath()
        }
    }

    private var discardAsk: Binding<Bool> {
        Binding(get: { pendingPick != nil || pendingClose },
                set: { if !$0 { pendingPick = nil; pendingClose = false } })
    }
}
