import SwiftUI
import FusionhaKit

/// The approver's Board on a phone (Final mock + "go with recommended",
/// 2026-10-18): no stage strip. Under "Board" a line names only what needs
/// the approver ("9 pending · 1 downloading"), each part a jump to its
/// section. Each stage is one grouped list under a pinned header with its
/// count; five rows, then "Show all". Empty stages get one quiet line.
/// Pending rows swipe to decide (with Undo) and hold for a menu.
struct RequestsBoardView: View {
    let onOpenThread: (MediaRequest) -> Void
    let onOpenHistory: (HistoryFilter) -> Void
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @Environment(RequestsNav.self) private var nav
    @State private var board = BoardModel()
    @State private var inbox = InboxModel()
    @State private var expanded: Set<RequestBoard.Column> = []
    @State private var declining: MediaRequest?
    @AppStorage("requests.board.peeked") private var peeked = false

    private var values: RequestsFilter.Values { nav.filter[.board] }
    private var key: String { "\(values.search)|\(values.requesterId ?? -1)|\(nav.filter.query(.board))" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RequestsViewHeader { if board.loaded { summary } }
            if !board.loaded {
                DiscoverEmptyState(message: "Loading the board…")
            } else {
                stages
            }
        }
        .task(id: key) {
            if !values.search.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            board.search = values.search
            board.userId = values.requesterId
            board.extra = RequestOrigin.query(values.origins)
            await board.poll(model.client)
        }
        .task {
            inbox.bind(model.client) { message, title, variant in model.toast(message, title: title, variant: variant) }
            inbox.viewerIsAdmin = model.me?.isAdmin == true
            await inbox.poll()
        }
        .onDisappear { inbox.flush() }
        .onChange(of: board.columns) {
            nav.remember(board.columns.values.flatMap { $0 })
            nav.resultCount = RequestBoard.Column.allCases.reduce(0) { $0 + board.count($1) }
        }
        .overlay(alignment: .bottom) {
            if let decision = inbox.pending {
                InboxUndoToast(decision: decision, onUndo: inbox.undo, onReason: inbox.setReason)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
            }
        }
        .animation(.snappy, value: inbox.pending)
        .sheet(item: $declining) { r in
            RejectDialog(request: r) { Task { await refresh() } }
        }
    }

    // MARK: Summary

    private var summary: some View {
        let parts = RequestBoardSummary.parts(pending: rows(.pending).count, downloading: board.count(.downloading),
                                              available: board.count(.available))
        return HStack(spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                if i > 0 { Text("·") }
                if let column = part.column {
                    Button { jump(column) } label: {
                        if let n = part.count { requestsCount(n, part.text) } else { Text(part.text) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(part.count.map(String.init) ?? "") \(part.text), jump to section")
                } else {
                    Text(part.text)
                }
            }
        }
    }

    private func jump(_ column: RequestBoard.Column) {
        expanded.remove(column)
        store.scrollTo = "board-\(column.rawValue)"
    }

    // MARK: Stages

    /// Pending leaves out rows the Undo is holding or sending.
    private func rows(_ column: RequestBoard.Column) -> [MediaRequest] {
        let items = board.columns[column] ?? []
        guard column == .pending else { return items }
        let hidden = Set(inbox.pending?.ids ?? []).union(inbox.sending)
        return items.filter { !hidden.contains($0.id) }
    }

    private var stages: some View {
        let empty = RequestBoard.Column.allCases.filter { rows($0).isEmpty && !board.failed($0) }
        return LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(RequestBoard.Column.allCases.filter { !empty.contains($0) }, id: \.self) { column in
                Section {
                    stageBody(column)
                } header: {
                    let items = rows(column)
                    let shared = RequestStageFacts.sharedRequester(items)
                    RequestsSectionHeader(title: column.label, count: column == .pending ? items.count : board.count(column),
                                          dot: column.tone.color, facts: facts(column, items, shared: shared))
                        .background(Theme.bg.padding(.horizontal, -16))
                }
                .id("board-\(column.rawValue)")
            }
            if !empty.isEmpty {
                Text(quietLine(empty))
                    .font(.system(size: 13)).foregroundStyle(Theme.dim)
                    .padding(.horizontal, 4).padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private func stageBody(_ column: RequestBoard.Column) -> some View {
        let items = rows(column)
        let shared = RequestStageFacts.sharedRequester(items)
        let open = expanded.contains(column)
        let shown = open ? items : Array(items.prefix(RequestStageFacts.preview))
        RequestsGroup {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, r in
                row(r, column: column, showRequester: shared == nil, peek: column == .pending && index == 0 && !peeked)
            }
            if items.count > RequestStageFacts.preview || (open && board.hasMore(column)) {
                RequestsShowAllRow(title: open ? (board.hasMore(column) ? "Load more" : "Show fewer")
                                             : "Show all \(column == .pending ? items.count : board.count(column))") {
                    if open && board.hasMore(column) {
                        Task { await board.loadMore(model.client, bucket: column.bucket) }
                    } else if open {
                        expanded.remove(column)
                    } else {
                        expanded.insert(column)
                    }
                }
            }
        }
        if board.failed(column) {
            Button("Couldn’t load this stage. Retry") { Task { await refresh() } }
                .font(.system(size: 13)).padding(.top, 6)
        }
        if let history = column.history, open {
            Button { onOpenHistory(history) } label: { Label("Older in History", systemImage: "arrow.right") }
                .font(.system(size: 13, weight: .semibold)).padding(.top, 8).padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func row(_ r: MediaRequest, column: RequestBoard.Column, showRequester: Bool, peek: Bool) -> some View {
        let line = BoardStageRow(request: r, column: column, showRequester: showRequester, compact: values.compact)
        if column == .pending && !inbox.isLocked(r, viewerId: model.me?.id) {
            BoardSwipeRow(onApprove: { approve(r) }, onDecline: { _ = inbox.decline(r, viewerId: model.me?.id) },
                          onDeclineWithReason: { declining = r }, peek: peek) {
                Button { onOpenThread(r) } label: { line }.buttonStyle(.plain)
            }
            .onAppear { if peek { Task { try? await Task.sleep(for: .seconds(3)); peeked = true } } }
            .contextMenu { BoardRowMenu(request: r, onApprove: { _ = approve(r) }, onDecline: { declining = r },
                                        onThread: { onOpenThread(r) }) }
        } else {
            Button { onOpenThread(r) } label: { line }
                .buttonStyle(.plain)
                .contextMenu { BoardRowMenu(request: r, onApprove: nil, onDecline: nil, onThread: { onOpenThread(r) }) }
        }
    }

    /// Approve needs the row's triage (space check); a low-space approve warns once.
    private func approve(_ r: MediaRequest) -> Bool {
        if inbox.approve(r, viewerId: model.me?.id) { return true }
        if let warning = TriageFacts.lowSpaceMessage(inbox.triage[r.id]), inbox.armedId == r.id {
            model.toast("\(warning) Swipe again to approve anyway.", title: nil, variant: .warning)
        } else if !TriageFacts.loaded(inbox.triage[r.id]) {
            model.toast("Checking free space. Try again in a moment.", title: nil, variant: .info)
        }
        return false
    }

    private func refresh() async {
        await board.refresh(model.client)
        await inbox.refresh()
    }

    /// "all by eafx · oldest 5d", "latest 2 h ago".
    private func facts(_ column: RequestBoard.Column, _ items: [MediaRequest], shared: String?) -> String? {
        var parts: [String] = []
        if let shared { parts.append(items.count > 1 ? "all by \(shared)" : shared) }
        switch column {
        case .pending:
            let oldest = TriageFacts.oldestAge(items)
            if !oldest.isEmpty { parts.append("oldest \(oldest)") }
        case .available:
            if let first = items.first { parts.append("latest " + ActFmt.relative(first.availableAt ?? first.decidedAt)) }
        default: break
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Nothing approved yet." / "Nothing pending, approved or downloading yet."
    private func quietLine(_ empty: [RequestBoard.Column]) -> String {
        let words = empty.map { $0.label.lowercased() }
        let list = words.count > 1 ? words.dropLast().joined(separator: ", ") + " or " + words.last! : words[0]
        return "Nothing \(list) yet."
    }
}
