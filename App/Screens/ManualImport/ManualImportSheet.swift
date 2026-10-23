import SwiftUI
import FusionhaKit

/// Manual Import for held downloads, native (the web's Manual Import modal in
/// its rescue mode): the reason strip, one block per title, a row per file,
/// and the footer that imports or finishes the download. Phone cards, the Duo
/// split (list | file) or the desktop table, by the sheet's own size; with
/// the open Duo's fold through it, always the split, meeting at the fold.
/// With no held downloads it is the folder scan (source bar, Browse…, Scan);
/// the system overflow also offers the web version as a fallback.
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
    /// The sheet's measured size (`layout`).
    @State private var size: CGSize = .zero
    /// The open iPhone Duo's fold through the sheet: the list before it, the
    /// file or the decision panel after it (`MISplitBody`).
    @State private var foldPanes: FoldColumns.Panes?

    init(downloadIds: [Int], client: APIClient?, onOpenWeb: @escaping () -> Void) {
        self.downloadIds = downloadIds
        self.onOpenWeb = onOpenWeb
        _session = State(initialValue: ManualImportSession(rescueIds: downloadIds, client: client))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Theme.bg.ignoresSafeArea())
                // On the fold the centred title would sit in the gutter.
                .navigationTitle(foldPanes == nil ? "Manual import" : "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { SheetCancelButton(title: "Close") { dismiss() } }
                    if layout == .split && session.barShows && session.scan != nil {
                        // The split's list column keeps Select all (the panel decides).
                        ToolbarItem(placement: .primaryAction) { MISelectUndecidedButton() }
                    }
                    // Two system items, no ⋯ menu (D1): the key stays in the
                    // bar, the web fallback goes to the system overflow.
                    ToolbarItem(placement: .primaryAction) {
                        Button("Status key", systemImage: "info.circle") { showKey = true }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Open on the web", systemImage: "safari") { dismiss(); onOpenWeb() }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // The split hosts the footer in its list pane (web `SplitBody`);
                    // the bulk bar takes its place while files are ticked.
                    if session.scan != nil && layout != .split && !barActive { MIFooter() }
                }
                .miBulkBar(active: barActive)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                .onGeometryChange(for: FoldColumns.Panes?.self) { proxy in
                    ManualImportLayout.foldPanes(width: Double(proxy.size.width), fold: GridFold(proxy).foldRange)
                } action: { foldPanes = $0 }
        }
        .environment(session)
        .sheet(isPresented: $showKey) { MIStatusKey() }
        .task { await session.start() }
        .task(id: model.me?.id) { session.canRemove = model.me.map { $0.has("system.admin") } ?? true }
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
        .interactiveDismissDisabled(session.working || session.applying != nil)
        // Unfolded: the page size, so the file rows use the inner display's
        // width (DC22); `layout` then picks cards, the split or the table from it.
        .presentationSizing(.page)
    }

    @ViewBuilder private var content: some View {
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
            if layout == .split {
                MISplitBody(scan: scan, detailId: $openId, folded: $folded,
                            lead: foldPanes.map { CGFloat($0.lead) }, gap: foldPanes.map { CGFloat($0.gap) } ?? 0) { pollRun += 1 }
            } else {
                ScrollView {
                    MIScanList(scan: scan, rowMode: rowMode, openId: $openId, folded: $folded) { pollRun += 1 }
                        .padding(.horizontal, Theme.pageGutter)
                        .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.immediately)
            }
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

    /// The sheet's own size picks the layout (ruling R4; web
    /// `useManualImportLayout`): the split at 720 and under on a split-capable
    /// screen, the table above 720, phone cards otherwise.
    private var layout: ManualImportLayout {
        if foldPanes != nil { return .split }
        return size == .zero ? .cards : ManualImportLayout.mode(width: Double(size.width), height: Double(size.height))
    }

    /// Files are ticked in a scan the bar serves, outside the split (whose
    /// right page is the decision panel).
    private var barActive: Bool {
        session.barShows && session.tickedCount > 0 && layout != .split
    }

    private var rowMode: MIRowMode {
        layout == .table ? .table(narrow: ManualImportLayout.tableIsNarrow(Double(size.width))) : .cards
    }
}
