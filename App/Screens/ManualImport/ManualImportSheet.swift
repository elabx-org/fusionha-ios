import SwiftUI
import FusionhaKit

/// Manual Import for held downloads, native (the web's Manual Import modal in
/// its rescue mode, phone layout): the reason strip, one block per title, a
/// row per file, and the footer that imports or finishes the download.
/// With no held downloads it is the folder scan (source bar, Browse…, Scan);
/// the ⋯ menu also offers the web version as a fallback.
struct ManualImportSheet: View {
    let downloadIds: [Int]
    let onOpenWeb: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var session: ManualImportSession
    @State private var openId: Int?
    @State private var showKey = false
    @State private var pollRun = 0
    @State private var folded: Set<String> = []

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
        @Bindable var session = session
        if session.folderMode && session.scan == nil {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MISourceBar()
                    folderState
                }
                .padding(.horizontal, Theme.pageGutter)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.immediately)
        } else if let scan = session.scan {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if session.folderMode { MISourceBar() }
                    if let strip = ManualImportHeldStrip(scan: scan, decide: session.plan.need) { MIHeldStripView(strip: strip) }
                    MIPackProgress()
                    MIVerdictStrip(rows: scan.rows, filter: $session.filter, probing: scan.probePending ?? 0,
                                   stalled: session.probeStalled) {
                        session.retryProbes()
                        pollRun += 1
                    }
                    let blocks = ManualImportBlock.group(scan.rows)
                    MIMatchBanner(blocks: blocks, filter: $session.filter)
                    ForEach(blocks) { block in
                        let shown = block.rows.filter(session.filter.matches)
                        if !shown.isEmpty {
                            MITitleSection(block: block, rows: shown, folded: foldBinding(block.key), openId: $openId)
                        }
                    }
                    if blocks.allSatisfy({ !$0.rows.contains(where: session.filter.matches) }) {
                        Button("No files match this filter. Show all") { session.filter = .all }
                            .buttonStyle(ActButtonStyle(kind: .ghost))
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

    @ViewBuilder private var folderState: some View {
        if session.scanning {
            HStack(spacing: 10) {
                ProgressView().tint(Theme.mut)
                Text("Scanning the folder…").font(.subheadline).foregroundStyle(Theme.mut)
            }
        } else if let error = session.loadError {
            Text(error).font(.footnote).foregroundStyle(Theme.danger)
        } else {
            Text("Pick a folder on the server. fusionha matches each video to a title in your library, and files import in place with no re-download.")
                .font(.subheadline).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func foldBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { folded.contains(key) },
                set: { if $0 { folded.insert(key) } else { folded.remove(key) } })
    }
}
