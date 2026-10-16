import SwiftUI
import FusionhaKit

/// Manual Import for held downloads, native (the web's Manual Import modal in
/// its rescue mode, phone layout): the reason strip, one block per title, a
/// row per file, and the footer that imports or finishes the download.
/// The folder-scan entry still opens the web page; this sheet's ⋯ menu also
/// offers the web version as a fallback.
struct ManualImportSheet: View {
    let downloadIds: [Int]
    let onOpenWeb: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var session: ManualImportSession
    @State private var openId: Int?
    @State private var showKey = false
    @State private var pollRun = 0

    init(downloadIds: [Int], client: APIClient?, onOpenWeb: @escaping () -> Void) {
        self.downloadIds = downloadIds
        self.onOpenWeb = onOpenWeb
        _session = State(initialValue: ManualImportSession(rescueIds: downloadIds, client: client))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Theme.bg.ignoresSafeArea())
                .navigationTitle("Manual import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { SheetCancelButton(title: "Close") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Status key", systemImage: "info.circle") { showKey = true }
                            Button("Open on the web", systemImage: "safari") { dismiss(); onOpenWeb() }
                        } label: { Label("More", systemImage: "ellipsis") }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if session.scan != nil { MIFooter() }
                }
        }
        .environment(session)
        .sheet(isPresented: $showKey) { MIStatusKey() }
        .task { await session.start() }
        .task(id: "\(session.scan?.scanId ?? 0)-\(pollRun)") { await session.pollProbes() }
        .task(id: session.scan?.scanId) {
            let items = Set(session.rows.filter { $0.target.isSeries }.compactMap(\.match.itemId))
            for item in items { await session.loadSeasons(itemId: item) }
        }
        .onChange(of: session.closing?.text) {
            guard let closing = session.closing else { return }
            model.toast(closing.text, title: "Manual import", variant: closing.warning ? .warning : .success)
            Task { await model.refreshQueue() }
            dismiss()
        }
        .interactiveDismissDisabled(session.working)
    }

    @ViewBuilder private var content: some View {
        if let scan = session.scan {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let strip = ManualImportHeldStrip(scan: scan, decide: session.plan.need) { MIHeldStripView(strip: strip) }
                    MIPackProgress()
                    if session.probeStalled {
                        Button("Checking the files stalled. Retry", systemImage: "arrow.clockwise") {
                            session.retryProbes()
                            pollRun += 1
                        }
                        .buttonStyle(ActButtonStyle(kind: .warn))
                    }
                    ForEach(blocks(scan.rows), id: \.key) { block in
                        blockHeader(block)
                        ForEach(block.rows) { row in MIRowView(row: row, openId: $openId) }
                    }
                }
                .padding(.horizontal, Theme.pageGutter)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.immediately)
        } else if let error = session.loadError {
            ContentUnavailableView {
                Label("Couldn't open the files", systemImage: "exclamationmark.triangle")
            } description: { Text(error) } actions: {
                ActAsyncButton(label: "Try again", kind: .primary) { await session.retryStart(); return session.loadError == nil }
                Button("Open on the web") { dismiss(); onOpenWeb() }.buttonStyle(ActButtonStyle(kind: .ghost))
            }
        } else {
            VStack(spacing: 12) {
                ProgressView().controlSize(.large).tint(Theme.mut)
                Text("Reading the files…").font(.subheadline).foregroundStyle(Theme.mut)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private struct Block { let key: String; let title: String; let year: Int?; let rows: [ManualImportRow] }

    /// One block per title; unmatched files sit last.
    private func blocks(_ rows: [ManualImportRow]) -> [Block] {
        var order: [String] = []
        var grouped: [String: [ManualImportRow]] = [:]
        for row in rows {
            let key = row.match.itemId.map { "item-\($0)" } ?? "none"
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(row)
        }
        order = order.filter { $0 != "none" } + order.filter { $0 == "none" }
        return order.map { key in
            let first = grouped[key]![0]
            return Block(key: key, title: key == "none" ? "No match" : (first.match.title ?? first.parsed.title ?? "—"),
                         year: key == "none" ? nil : first.match.year, rows: grouped[key]!)
        }
    }

    private func blockHeader(_ block: Block) -> some View {
        let attention = block.rows.filter { !$0.committed && $0.status != "ready" }.count
        let ticked = block.rows.filter { session.selected.contains($0.rowId) }.count
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(block.title).font(Theme.display(22)).foregroundStyle(Theme.txt).lineLimit(1)
            if let year = block.year { Text(String(year)).font(.subheadline).foregroundStyle(Theme.mut) }
            Spacer(minLength: 0)
            Text("\(block.rows.count) file\(block.rows.count == 1 ? "" : "s")"
                 + (attention > 0 ? " · \(attention) to look at" : "") + " · \(ticked) selected")
                .font(.caption).foregroundStyle(Theme.mut)
        }
        .padding(.top, 8)
    }
}
