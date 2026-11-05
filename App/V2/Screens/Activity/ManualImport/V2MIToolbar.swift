import SwiftUI
import FusionhaKit

/// The sheets Manual Import's bar opens. v1's views, so nothing v1 offered
/// becomes unreachable (parity): the status key, Edit all, and the classic
/// Manual Import (every per-file tool, the table and the folder tools).
enum V2MISheet: String, Identifiable {
    case key, editAll, classic
    var id: String { rawValue }
}

/// Close; then the status key and More (mock: info + ⋯ in one capsule).
struct V2MIToolbar: ToolbarContent {
    let session: ManualImportSession
    let busy: Bool
    @Binding var sheet: V2MISheet?
    let close: () -> Void
    let openWeb: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark", action: close)
                .disabled(busy)
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Status key", systemImage: "info.circle") { sheet = .key }
        }
        ToolbarItem(placement: .primaryAction) { more }
    }

    private var more: some View {
        @Bindable var session = session
        let open = session.rows.filter { !$0.committed }
        return Menu("More", systemImage: "ellipsis") {
            Section {
                Picker(selection: $session.importMode) {
                    ForEach(ManualImportMode.allCases) { mode in
                        Text("\(mode.label) · \(mode.hint)").tag(mode)
                    }
                } label: {
                    Label("Import mode", systemImage: "arrow.triangle.branch")
                    Text(session.importMode.label)
                }
                .pickerStyle(.menu)
                Button("Edit all \(open.count)…", systemImage: "pencil") { sheet = .editAll }
                    .disabled(open.isEmpty || busy)
            }
            Section {
                Button("Classic Manual Import", systemImage: "list.bullet.rectangle") { sheet = .classic }
                    .disabled(busy)
                Button("Open on the web", systemImage: "safari", action: openWeb)
            }
        }
    }
}

extension View {
    /// The bar's sheets. The classic view runs its own session over the same
    /// held downloads; closing it opens them again here so both agree.
    func v2MISheets(_ sheet: Binding<V2MISheet?>, downloadIds: [Int], client: APIClient?,
                    openWeb: @escaping () -> Void) -> some View {
        modifier(V2MISheets(sheet: sheet, downloadIds: downloadIds, client: client, openWeb: openWeb))
    }
}

private struct V2MISheets: ViewModifier {
    @Binding var sheet: V2MISheet?
    let downloadIds: [Int]
    let client: APIClient?
    let openWeb: () -> Void
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content
            .duoPageSheet(item: Binding(get: { sheet == .classic ? nil : sheet }, set: { sheet = $0 })) { which in
                if which == .editAll {
                    MIBulkSheet(title: "Edit all \(session.rows.filter { !$0.committed }.count)",
                                rows: session.rows.filter { !$0.committed })
                        .environment(session)
                } else {
                    MIStatusKey()
                }
            }
            // Across both pages on the open Duo, as v1 opens it.
            .duoPageSheet(isPresented: Binding(get: { sheet == .classic }, set: { if !$0 { sheet = nil } }),
                          placement: .twoPages) {
                ManualImportSheet(downloadIds: downloadIds, client: client, onOpenWeb: openWeb)
                    .environment(model)
            }
            .onChange(of: sheet) { old, new in
                // The classic view may have changed the rows: start the choices afresh too.
                if old == .classic, new == nil {
                    store.draft = MIDraft()
                    Task { await session.retryStart() }
                }
            }
    }
}
