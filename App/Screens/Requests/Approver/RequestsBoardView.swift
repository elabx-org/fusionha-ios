import SwiftUI
import FusionhaKit

/// The approver's board (web `RequestsBoard`, phone layout): a search and
/// requester filter, density, then "Pending · 3 · Approved · 2 …" pills over
/// one column at a time (swipe sideways to move between them). Available and
/// Declined show the last 7 days and hand off to History.
struct RequestsBoardView: View {
    let onOpenThread: (MediaRequest) -> Void
    let onOpenHistory: (HistoryFilter) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var board = BoardModel()
    @State private var column: RequestBoard.Column = .pending
    @State private var compact = false
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar
            if !board.loaded {
                DiscoverEmptyState(message: "Loading the board…")
            } else {
                pills
                columnView
                    .id(column)
                    .transition(.opacity)
                    .gesture(DragGesture(minimumDistance: 30).onEnded(swipe))
            }
        }
        .task(id: "\(query)-\(board.userId ?? -1)") {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            board.search = query
            await board.poll(model.client)
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(Theme.dim)
                    TextField("Filter by title or person", text: $query)
                        .font(.system(size: 14))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 12).frame(height: 38)
                .background(Theme.panel2, in: Capsule())
                Picker("Card density", selection: $compact) {
                    Image(systemName: "rectangle.grid.1x2").tag(false).accessibilityLabel("Comfortable")
                    Image(systemName: "list.bullet").tag(true).accessibilityLabel("Compact")
                }
                .pickerStyle(.segmented)
                .frame(width: 92)
            }
            if !board.people.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        personChip(nil, "Anyone")
                        ForEach(board.people, id: \.id) { p in personChip(p.id, p.displayName) }
                    }
                }
            }
        }
    }

    private func personChip(_ id: Int?, _ name: String) -> some View {
        let on = board.userId == id
        return Button { board.userId = on && id != nil ? nil : id } label: {
            Text(name).font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(on ? Theme.onAccent : Theme.txt)
                .padding(.horizontal, 11).frame(height: 30)
                .background(on ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.panel2), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Columns

    private var pills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(RequestBoard.Column.allCases, id: \.self) { c in
                    let on = c == column
                    Button { select(c) } label: {
                        Text("\(c.label) · \(board.countLabel(c))")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(on ? Theme.txt : c.tone.color)
                            .padding(.horizontal, 11).frame(height: 30)
                            .background(c.tone.color.opacity(on ? 0.3 : 0.13), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var columnView: some View {
        let items = board.columns[column] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(column.tone.color).frame(width: 8, height: 8)
                Text(column.label).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                Text(board.countLabel(column)).font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.mut)
                if column == .pending && board.waiting > 0 {
                    Text("\(board.waiting) waiting").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.miss)
                }
                Spacer()
                if column.history != nil {
                    Text("last \(RequestBoard.terminalDays) d").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                }
            }
            ForEach(items) { r in
                Button { onOpenThread(r) } label: {
                    if compact { BoardCardCompact(request: r) } else { BoardCardView(request: r, column: column) }
                }
                .buttonStyle(.plain)
            }
            if board.failed(column) {
                Button("Couldn’t load this column. Retry") { Task { await board.refresh(model.client) } }
                    .font(.system(size: 13))
            } else if items.isEmpty && !board.hasMore(column) {
                Text(column.history != nil ? "Nothing in the last \(RequestBoard.terminalDays) days" : "Nothing here")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
            }
            if board.hasMore(column) {
                Button(board.buckets[column.bucket]?.loadingMore == true ? "Loading…" : "Load more") {
                    Task { await board.loadMore(model.client, bucket: column.bucket) }
                }
                .buttonStyle(.discover(.subtle))
            }
            if board.capped(column) {
                Text("Showing the first \(RequestBoard.maxPages * RequestBoard.page)\(column.history == nil ? " — search or pick a requester to narrow" : "")")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            if let history = column.history {
                Button { onOpenHistory(history) } label: { Label("View all in History", systemImage: "arrow.right") }
                    .font(.system(size: 13, weight: .semibold))
            }
        }
    }

    private func select(_ c: RequestBoard.Column) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { column = c }
    }

    private func swipe(_ value: DragGesture.Value) {
        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
        let all = RequestBoard.Column.allCases
        guard let i = all.firstIndex(of: column) else { return }
        let next = value.translation.width < 0 ? min(all.count - 1, i + 1) : max(0, i - 1)
        select(all[next])
    }
}
