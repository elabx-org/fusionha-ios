import SwiftUI
import FusionhaKit

/// Phone and folded Duo (mock `miPhone` / `miOuter`): the header, the
/// controls, then the cards (or the files) in one column; a card opens its
/// files on a pushed page. The footer stays pinned over a fade, and gives
/// way to the bulk bar while files are ticked.
struct V2MIPhoneBody: View {
    let push: (V2MIRoute) -> Void
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                V2MIHeader(helps: true)
                V2MIControls()
                if store.segment == .groups {
                    MIGroupsView(lean: false) { push(.group($0)) }
                } else {
                    V2MIFilesList { push(.file($0)) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .keepsScrollOffset(read: { [store] in store.listY }, write: { [store] y in store.listY = y })
        .scrollIndicators(.hidden)
        .v2MIFooter(hidden: bulkActive)
        .v2MIBulkBar(active: bulkActive)
    }

    private var bulkActive: Bool { store.segment == .files && session.tickedCount > 0 }
}

/// A page pushed over the list: one card's files, or one file (v1's file
/// detail, so every per-file tool stays one tap away).
struct V2MIRoutePage: View {
    let route: V2MIRoute
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        switch route {
        case .group(let problem):
            ScrollView {
                MIGroupDetail(problem: problem)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(ManualImportDecide.downloadName(session.rows) ?? "Manual Import")
            .toolbarTitleDisplayMode(.inline)
            .v2MIFooter()
        case .file(let id):
            V2MIFilePage(rowId: id)
                .navigationTitle(fileTitle(id))
                .toolbarTitleDisplayMode(.inline)
        }
    }

    private func fileTitle(_ id: Int) -> String {
        guard let row = session.rows.first(where: { $0.rowId == id }) else { return "File" }
        let code = ManualImportBulk.shortCode(row)
        return V2MIEpisodeNames.title(row, session).map { "\(code) · \($0)" } ?? code
    }
}

/// The open Duo (mock `miSplit`): the list on the left (flat 40%, book the
/// left page) and, on the right, the open card's files, the ticked files'
/// panel or one file, with the footer pinned under it. Flat, a hairline
/// splits them; book pose keeps the fold's gutter.
struct V2MISplitBody: View {
    let panes: V2MIPanes
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    V2MIHeader(helps: panes.gap == 0)
                    V2MIControls()
                    if store.segment == .groups {
                        MIGroupsView(lean: true) { store.focus = $0 }
                    } else {
                        V2MIFilesList { store.fileFocus = $0 }
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 18)
                .padding(.vertical, 12)
            }
            .keepsScrollOffset(read: { [store] in store.listY }, write: { [store] y in store.listY = y })
            .scrollIndicators(.hidden)
            .frame(width: panes.lead)
            if panes.gap > 0 {
                Color.clear.frame(width: panes.gap)
            } else {
                Theme.line.frame(width: 1 / displayScale).ignoresSafeArea()
            }
            right.frame(maxWidth: .infinity)
        }
        .task(id: store.groups(session).map(\.problem)) { focusFirst() }
    }

    @ViewBuilder private var right: some View {
        if store.segment == .files && session.tickedCount > 0 {
            V2MIBulkPanel()
        } else if store.segment == .files, let id = store.fileFocus, session.rows.contains(where: { $0.rowId == id }) {
            V2MIFilePage(rowId: id)
        } else if let focus = store.focus, store.group(focus, session) != nil {
            ScrollView {
                MIGroupDetail(problem: focus)
                    .padding(.leading, panes.gap > 0 ? 20 : 26)
                    .padding(.trailing, 24)
                    .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            .v2MIFooter()
        } else {
            ContentUnavailableView("Nothing to decide", systemImage: "checkmark.circle",
                                   description: Text("Every file of this download is decided."))
                .v2MIFooter()
        }
    }

    /// The first card that still needs a decision, else the first card.
    private func focusFirst() {
        let groups = store.groups(session)
        if let focus = store.focus, groups.contains(where: { $0.problem == focus }) { return }
        let rows = session.rows
        store.focus = (groups.first { g in g.rows.contains { store.draft.choice($0, rows: rows) == nil && !$0.committed } }
            ?? groups.first)?.problem
    }
}
