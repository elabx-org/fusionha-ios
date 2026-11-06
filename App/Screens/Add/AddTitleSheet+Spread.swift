import SwiftUI
import FusionhaKit

// MARK: - Add title on the open iPhone Duo (Duo Add mock, part A)
//
// With the fold through the sheet (`duoPageSheet(.twoPages)`), Add is a
// spread: Find on the left page (kinds, source, search, the results or
// trending grid), the pick's setup on the right. Until a pick, the right page
// shows the top result (or #1 trending) once the results settle, never per
// keystroke. Picking another title over a setup with choices asks first.
// Folded, in portrait and on a phone it stays one flow: search, then push.

extension AddTitleSheet {
    func spread(_ panes: FoldColumns.Panes) -> some View {
        HStack(spacing: 0) {
            findPage
                .frame(width: CGFloat(panes.lead))
                .overlay(alignment: .trailing) {
                    // Flat: the pages meet at the hinge line, nothing on it.
                    if panes.gap == 0 { Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea() }
                }
            // Book: the fold's gutter, holding nothing.
            Color.clear.frame(width: CGFloat(panes.gap))
            NavigationStack(path: $path) {
                rightPage
                    .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                    .navigationDestination(for: AddDetailsRoute.self) { details in
                        previewPage(details.route)
                            .modifier(ZoomTransition(id: details.zoomId, namespace: zoomSpace))
                    }
                    .navigationDestination(for: PreviewRoute.self) { route in
                        previewPage(route)
                    }
            }
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Discard this title's setup?", isPresented: discardAsk, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                if let pendingPick { startFlow(pendingPick) }
                pendingPick = nil
            }
            Button("Keep editing", role: .cancel) { pendingPick = nil }
        }
    }

    /// The right page: the pick's setup, a requester's request, or a hint.
    @ViewBuilder
    var rightPage: some View {
        if let flow {
            // Search stays on the left page: no "Search again" here.
            AddConfigView(flow: flow, onSearchAgain: nil, onViewDetails: viewDetailsAction(flow),
                          onClose: { dismiss() }, onAdded: { added($0, flow: flow) },
                          zoom: flow.pick.tmdbResult == nil ? nil : (id: heroZoomId(flow), namespace: zoomSpace))
                .id(flow.pick.key)
                .transition(.opacity)
        } else if let requestPick {
            RequestModal(pick: requestPick, formSized: false) { Task { await model.refreshShell() } }
                .id(requestPick.id)
        } else {
            spreadHint
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCancelButton(title: "Close") { dismiss() }
                    }
                }
        }
    }

    /// Before a pick, with no result to show: never a blank page.
    var spreadHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Theme.dim)
                .accessibilityHidden(true)
            Text(model.requestScoped ? "Pick a title to request it" : "Pick a title to set it up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.txt)
            Text("Its versions, folders and monitoring open on this page.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(AddSetupGround(look: look, backdrop: nil, poster: nil))
    }

    /// A pick from Find. On the spread, a pick over a setup with choices asks
    /// first; tapping the title already shown makes it the person's own.
    func choose(_ pick: AddPick) {
        guard foldPanes != nil, initialPick == nil, let flow else { return startFlow(pick) }
        if flow.pick.key == pick.key {
            autoPicked = false
        } else if flow.touched {
            pendingPick = pick
        } else {
            startFlow(pick)
        }
    }

    private var discardAsk: Binding<Bool> {
        Binding(get: { pendingPick != nil }, set: { if !$0 { pendingPick = nil } })
    }

    // MARK: The top result on the right page

    /// What the right page shows before a pick: the first result not already
    /// in the library, or #1 trending while the field is empty.
    var spreadCandidate: AddPick? {
        guard foldPanes != nil, initialPick == nil, !model.requestScoped else { return nil }
        if !term.isEmpty && source == .tvdb {
            return tvdbResults.first { $0.inLibrary != true }.map(AddPick.tvdb)
        }
        return (term.isEmpty ? trending : results).first { !$0.inLibrary }.map(AddPick.tmdb)
    }

    var spreadCandidateKey: String { spreadCandidate?.key ?? "" }

    /// Shows the candidate once the results have settled (~400 ms), only while
    /// nothing was picked by hand or the shown one has no choices yet.
    func previewTopResult() async {
        guard let candidate = spreadCandidate else { return }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled, requestPick == nil else { return }
        let replaceable = flow == nil || (autoPicked && flow?.touched != true)
        if replaceable && flow?.pick.key != candidate.key { startFlow(candidate, auto: true) }
    }
}
