import SwiftUI
import FusionhaKit

/// Settings › Media Management › Import Library (web `ImportLauncher`, req #9):
/// the durable launcher for the resumable triage workspace. Drafts to resume,
/// a root picker (tier and kind inferred from each path, tap to change) that
/// opens a new session, and the recent imports with their post-import analysis.
struct ImportLibrarySettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var roots: [RootFolder]?
    @State private var drafts: [LibraryImportSummary] = []
    @State private var recent: [LibraryImportSummary] = []
    @State private var picks: [Int: ImportRootChoice] = [:]
    @State private var error: String?
    @State private var starting = false
    @State private var open: ImportOpenSession?

    private var rootList: [RootFolder] { roots ?? [] }
    private var chosen: [RootFolder] { rootList.filter { pick($0).selected } }
    private var allSelected: Bool { !rootList.isEmpty && chosen.count == rootList.count }
    private var analyzing: Bool { recent.contains { $0.enrichment?.state == "analyzing" } }

    var body: some View {
        SettingsForm(slug: "import") {
            if let error { SettingsLoadingRow(error: error) }
            if !drafts.isEmpty {
                SettingsSection("In progress") {
                    ForEach(drafts) { d in
                        ImportResumeCard(draft: d, onResume: { open = ImportOpenSession(id: d.id) },
                                         onDiscard: { await discard(d) })
                    }
                }
            }
            startSection
            if !recent.isEmpty {
                ImportRecentSection(recent: recent,
                                    onView: { open = ImportOpenSession(id: $0) },
                                    onChanged: { await loadSessions() })
            }
            SettingsSection(footer: "Scan & review (or Resume) opens the full-screen workspace where you triage every match; closing it returns you here. The draft auto-saves as you work, so leaving and coming back is lossless, and a committed import drops into Recent.") {
                Label("How this works: this panel is the durable launcher.", systemImage: "info.circle")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .task(id: analyzing) {
            while analyzing, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                await loadSessions()
            }
        }
        .fullScreenCover(item: $open, onDismiss: { Task { await loadSessions() } }) { s in
            ImportWorkspaceSheet(sessionId: s.id, client: model.client)
        }
    }

    // MARK: Start a new import

    @ViewBuilder
    private var startSection: some View {
        if roots == nil, error == nil {
            SettingsLoadingRow()
        } else if rootList.isEmpty {
            SettingsSection("Start a new import") {
                Text("No root folders yet — add one under Settings › Root Folders first.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        } else {
            SettingsSection("Start a new import",
                            footer: "Choose the roots to scan — the tier is inferred from each path (/movies-4k → 4K) and drives which version adopted files attach to.") {
                Button(allSelected ? "Deselect all" : "Select all \(rootList.count)") { setAll(!allSelected) }
                ForEach(rootList) { root in
                    ImportRootPickRow(path: root.path, choice: pick(root)) { patch(root, $0) }
                }
                HStack {
                    Text("\(chosen.count) of \(rootList.count) roots selected")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    Spacer(minLength: 8)
                    Button(starting ? "Starting…" : "Scan & review \(LibraryImportRules.plural(chosen.count, "root"))") {
                        Task { await start() }
                    }
                    .buttonStyle(.web(.primary))
                    .disabled(chosen.isEmpty || starting)
                }
            }
        }
    }

    /// A root starts unselected: importing a library is deliberate.
    private func pick(_ root: RootFolder) -> ImportRootChoice {
        picks[root.id] ?? ImportRootChoice(tier: LibraryImportRules.inferTier(root.path),
                                           kind: LibraryImportRules.inferKind(root.path), selected: false)
    }

    private func patch(_ root: RootFolder, _ choice: ImportRootChoice) { picks[root.id] = choice }

    private func setAll(_ selected: Bool) {
        for root in rootList {
            var c = pick(root)
            c.selected = selected
            picks[root.id] = c
        }
    }

    // MARK: Loading and actions

    private func load() async {
        guard let client = model.client else { return }
        do {
            roots = try await client.rootFolders()
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the root folders.")
        }
        await loadSessions()
    }

    private func loadSessions() async {
        guard let client = model.client else { return }
        async let d = try? client.libraryImportSessions(status: "draft")
        async let c = try? client.libraryImportSessions(status: "committed", limit: 20)
        if let list = await d { drafts = list }
        if let list = await c { recent = list }
    }

    private func start() async {
        guard let client = model.client, !chosen.isEmpty else { return }
        let body = chosen.map { root -> LibraryImportRootPick in
            let c = pick(root)
            return LibraryImportRootPick(rootFolderId: root.id, tier: c.tier, kind: c.kind)
        }
        starting = true
        defer { starting = false }
        do {
            let session = try await client.startLibraryImport(body)
            open = ImportOpenSession(id: session.id)
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t start the import.")
        }
    }

    private func discard(_ draft: LibraryImportSummary) async {
        guard let client = model.client else { return }
        do {
            _ = try await client.discardLibraryImport(id: draft.id)
            await loadSessions()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t discard this draft.")
        }
    }
}

/// The session the workspace is open on.
struct ImportOpenSession: Identifiable, Hashable {
    let id: Int
}

/// One root's picker state: the tier and kind to scan it as, and whether it's in.
struct ImportRootChoice: Hashable {
    var tier: QualityTier
    var kind: MediaKind
    var selected: Bool
}
