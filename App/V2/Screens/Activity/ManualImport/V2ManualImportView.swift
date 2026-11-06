import SwiftUI
import FusionhaKit

/// v2's Manual Import for held downloads (slice S9, mock activity-mi.js):
/// the pack's files grouped by problem, each card with its problem, its
/// choices and Fusionha's pick where the server gives one; Files is the
/// second segment. Phone and folded Duo: one column, a card opens its files.
/// Open Duo flat: the list 40 | the open card 60, no gap; book pose: the
/// list and the card either side of the fold's gutter. Everything chosen is
/// applied at once from the footer through v1's `ManualImportSession`.
/// Folder scans stay v1's `ManualImportSheet` (source bar, Browse, Scan).
struct V2ManualImportView: View {
    static let override = ManualImportSheetOverride { ids, client, onOpenWeb in
        ids.isEmpty
            ? AnyView(ManualImportSheet(downloadIds: ids, client: client, onOpenWeb: onOpenWeb))
            : AnyView(V2ManualImportHost(downloadIds: ids, client: client, onOpenWeb: onOpenWeb))
    }

    let downloadIds: [Int]
    let onOpenWeb: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Set on a page of the open Duo: Close goes through the cover's guard.
    @Environment(DuoPageDismissGuard.self) private var pageGuard: DuoPageDismissGuard?
    @State private var session: ManualImportSession
    @State private var store = V2MIDraftStore()
    @State private var panes: V2MIPanes?
    @State private var path: [V2MIRoute] = []
    @State private var askingClose = false
    @State private var sheet: V2MISheet?
    @State private var pollRun = 0

    /// The window's kept models (`V2MIKept`), so a fold keeps the scan,
    /// the choices and the open card; nil starts fresh.
    private let kept: V2MIKept?

    init(downloadIds: [Int], client: APIClient?, kept: V2MIKept? = nil, onOpenWeb: @escaping () -> Void) {
        self.downloadIds = downloadIds
        self.onOpenWeb = onOpenWeb
        self.kept = kept
        _session = State(initialValue: kept?.session ?? ManualImportSession(rescueIds: downloadIds, client: client))
        _store = State(initialValue: kept?.store ?? V2MIDraftStore())
        _path = State(initialValue: kept?.path ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .v2PageGround(art: nil)
                .navigationTitle("Manual Import")
                .toolbarTitleDisplayMode(.inline)
                .toolbar { V2MIToolbar(session: session, busy: busy, sheet: $sheet, close: attemptClose, openWeb: openWeb) }
                .navigationDestination(for: V2MIRoute.self) { route in
                    V2MIRoutePage(route: route).v2PageGround(art: nil)
                }
                .onGeometryChange(for: V2MIPanes?.self) { V2MILayout.panes($0) } action: { panes = $0 }
        }
        .v2MISheets($sheet, downloadIds: downloadIds, client: session.client, openWeb: openWeb)
        .environment(session)
        .environment(store)
        .task { await session.start() }
        .task(id: model.me?.id) { session.canRemove = model.me.map { $0.has("system.admin") } ?? true }
        .task(id: "\(session.scan?.scanId ?? 0)-\(pollRun)") { await session.pollProbes() }
        .task(id: session.scan?.scanId) {
            let items = Set(session.rows.filter { $0.target.isSeries }.compactMap(\.match.itemId))
            for item in items { await session.loadSeasons(itemId: item) }
        }
        .onChange(of: session.closing?.text) { closeWithToast() }
        .onChange(of: session.scan?.rows) { store.draft.prune(session.rows) }
        // v1 ticks its default selection on load; here ticks are only the
        // Files view's, so a new scan starts with none (else Close asks and
        // the fallback footer would import the ticked files directly).
        .onChange(of: session.scan?.scanId) { session.selected = [] }
        // Fold continuity: the split's open card and the phone's pushed page are one.
        .onChange(of: panes == nil, initial: true) { _, phone in
            var next = path
            V2MIFoldRoute.reconcile(split: !phone, path: &next, store: store)
            if next != path { path = next }
        }
        .onChange(of: path) { kept?.path = path }
        .modifier(MIAutoClose(session: session))
        .interactiveDismissDisabled(busy)
        .duoPageDismiss(busy ? .busy : dirty ? .confirm(Self.closeQuestion) : .allowed)
        .confirmationDialog(Self.closeQuestion, isPresented: $askingClose, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep deciding", role: .cancel) {}
        }
        .presentationSizing(.page)
    }

    private static let closeQuestion = "Close Manual Import? Your choices here aren’t applied."

    private var busy: Bool { session.working || session.applying != nil || store.applying }
    private var dirty: Bool { store.dirty || !session.selected.isEmpty }

    @ViewBuilder private var content: some View {
        if session.scan != nil {
            if let panes {
                V2MISplitBody(panes: panes)
            } else {
                V2MIPhoneBody { path.append($0) }
            }
        } else if let error = session.loadError {
            ContentUnavailableView {
                Label(downloadIds.count > 1 ? "Couldn't open these downloads" : "Couldn't open this download",
                      systemImage: "exclamationmark.triangle")
            } description: { Text(error) } actions: {
                Button("Try again") { Task { await session.retryStart() } }.buttonStyle(.glassProminent)
                Button("Open on the web") { openWeb() }.buttonStyle(.glass)
            }
        } else {
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text(ManualImportCopy.rescueLoading(count: downloadIds.count))
                    .font(.subheadline).foregroundStyle(Theme.mut).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Close: on a Duo page through the cover's guard; in a sheet, asks while choices are unapplied.
    private func attemptClose() {
        if let pageGuard { return pageGuard.requestClose() }
        guard !busy else { return }
        if dirty { askingClose = true } else { dismiss() }
    }

    private func openWeb() {
        dismiss()
        onOpenWeb()
    }

    /// The toast names the title and the outcome (mock "done"); no Undo,
    /// since the server has none for a decide.
    private func closeWithToast() {
        guard let closing = session.closing else { return }
        if let id = session.soleDownload, session.finishedHere.contains(id) {
            let mine = session.rows.filter { ManualImportDecide.downloadId($0, session.scan) == id }
            let toast = MIProblemCopy.doneToast(mine.isEmpty ? session.rows : mine, finish: session.finishResults[id])
            model.toast(toast.detail, title: toast.title, variant: .success, duration: MIScreenshot.closingToastDuration)
        } else {
            model.toast(closing.text, title: "Manual Import", variant: closing.warning ? .warning : .success,
                        duration: MIScreenshot.closingToastDuration)
        }
        Task { await model.refreshQueue() }
        dismiss()
    }
}

/// A page pushed over the list on the phone and the folded Duo.
enum V2MIRoute: Hashable {
    case group(MIProblem)
    case file(Int)
}

/// The open Duo's split (mock `miSplit`): flat, the list 40% (at least 300)
/// and the card the rest with no gap; book pose, v1's halves either side of
/// the fold's gutter. Wide windows without a fold take the flat split too.
struct V2MIPanes: Equatable {
    let lead: CGFloat
    /// The fold's gutter (book pose), else 0.
    let gap: CGFloat
}

enum V2MILayout {
    static func panes(_ proxy: GeometryProxy) -> V2MIPanes? {
        let width = Double(proxy.size.width)
        let fold = FoldInfo(proxy)
        if let posture = fold.posture, let x = fold.vertical ?? fold.flatVertical, posture.reservesFold {
            let book = ManualImportLayout.foldPanes(width: width, fold: Double(x.lowerBound)...Double(x.upperBound))
            return book.map { V2MIPanes(lead: CGFloat($0.lead), gap: CGFloat($0.gap)) }
        }
        guard width >= 700 else { return nil }
        let lead = max((width * 0.4).rounded(), ManualImportLayout.minDuoList)
        return width - lead >= 360 ? V2MIPanes(lead: CGFloat(lead), gap: 0) : nil
    }
}
