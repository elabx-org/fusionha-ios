import SwiftUI
import FusionhaKit

/// The folder scan's source bar (web `SourceBar`): the path, Browse… and
/// Scan. Folds to "Change folder" once a scan is showing. The last folder is
/// remembered on this device.
struct MISourceBar: View {
    @Environment(ManualImportSession.self) private var session
    @AppStorage("fusionha.manualImport.lastFolder") private var path = ""
    @State private var browsing = false
    @State private var folded = false

    var body: some View {
        Group {
            if folded && session.scan != nil {
                Button("Change folder", systemImage: "folder") { folded = false }
                    .buttonStyle(ActButtonStyle(kind: .ghost))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder").foregroundStyle(Theme.mut)
                        TextField("/downloads/complete", text: $path)
                            .font(.system(size: 14, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit { scan() }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.panel, in: .rect(cornerRadius: 12))
                    HStack(spacing: 8) {
                        Button("Browse…", systemImage: "folder.badge.gearshape") { browsing = true }
                            .buttonStyle(ActButtonStyle(kind: .ghost))
                        Spacer(minLength: 0)
                        Button(session.scanning ? "Scanning…" : "Scan", systemImage: "magnifyingglass") { scan() }
                            .buttonStyle(ActButtonStyle(kind: .primary))
                            .disabled(path.trimmingCharacters(in: .whitespaces).isEmpty || session.scanning)
                    }
                }
            }
        }
        .sheet(isPresented: $browsing) {
            MIFolderBrowser(start: path.isEmpty ? nil : path) { picked in
                path = picked
                scan()
            }
        }
    }

    private func scan() {
        Task {
            await session.scanFolder(path)
            if session.scan != nil, session.loadError == nil { folded = true }
        }
    }
}

/// Select source folder (web `FolderBrowser`): crumbs, the parent, the
/// subfolders, and "Use this folder".
struct MIFolderBrowser: View {
    let start: String?
    let onPick: (String) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var path: String?
    @State private var page: ManualImportBrowse?
    @State private var failed = false

    init(start: String?, onPick: @escaping (String) -> Void) {
        self.start = start
        self.onPick = onPick
        _path = State(initialValue: start ?? "/")
    }

    var body: some View {
        NavigationStack {
            List {
                if let page {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(page.crumbs.enumerated()), id: \.element.path) { i, c in
                                    if i > 1 { Text("›").foregroundStyle(Theme.dim) }
                                    Button(c.name) { path = c.path }
                                        .font(.system(size: 13, weight: c.path == page.path ? .bold : .regular, design: .monospaced))
                                        .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    Section {
                        if let parent = page.parent {
                            Button { path = parent } label: { Label("..", systemImage: "arrow.turn.left.up") }
                        }
                        ForEach(page.entries) { e in
                            Button { path = e.path } label: { Label(e.name, systemImage: "folder") }
                        }
                        if page.entries.isEmpty { Text("No subfolders here.").foregroundStyle(Theme.mut) }
                    }
                } else if failed {
                    Text("That path could not be read. Pick a parent folder.").foregroundStyle(Theme.mut)
                    Button("Start at /") { path = "/" }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .tint(Theme.txt)
            .navigationTitle("Select source folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this folder") {
                        onPick(page?.path ?? path ?? "/")
                        dismiss()
                    }
                    .disabled(page == nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(page?.path ?? path ?? "/")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.mut)
                    .lineLimit(1).truncationMode(.head)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    .padding(.horizontal, 12)
            }
        }
        .task(id: path) { await load() }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            page = try await client.manualImportBrowse(path: path)
            failed = false
        } catch {
            page = nil
            failed = true
        }
    }
}
