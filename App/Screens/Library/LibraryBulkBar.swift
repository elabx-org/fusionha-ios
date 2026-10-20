import SwiftUI
import FusionhaKit

// MARK: - Bulk action bar (BulkActionBar.tsx)

/// Select mode's bar as a system bottom bar (ruling Q-DC4), so iOS can move
/// it into the iPhone Duo's vertical bar; the tab bar steps aside while
/// selecting (a task-focused view). Selection ("N selected · of M filtered",
/// Select all, Clear), the bulk Actions with the count as their badge (the
/// HIG's badge for an inline count), and Done. The bar sits in the tab's safe
/// area, so the shell's toasts clear it (`ToastAnchor`).
struct LibrarySelectBar: ViewModifier {
    @Environment(AppModel.self) private var model
    let active: Bool
    let visibleIds: [Int]
    @State private var profiles: [QualityProfile] = []
    @State private var showingRoot = false
    @State private var confirmingDelete = false

    func body(content: Content) -> some View {
        let count = model.selection.count
        content
            .toolbar {
                if active {
                    ToolbarItemGroup(placement: .bottomBar) {
                        selectionMenu(count)
                        Spacer()
                        actionsMenu(count)
                        Button("Done", systemImage: "checkmark") { model.exitSelectMode() }
                    }
                }
            }
            .task(id: active) {
                if active && profiles.isEmpty { profiles = (try? await model.client?.qualityProfiles()) ?? [] }
            }
            .sheet(isPresented: $showingRoot) {
                ChangeRootSheet()
                    .presentationDetents([.mediumFitting, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.panel)
            }
            .confirmationDialog("Delete \(count) \(count == 1 ? "title" : "titles")?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.bulk(nil, "Couldn't delete the selection") { client, ids in
                        try await client.bulkDelete(BulkDeleteRequest(itemIds: ids, deleteFiles: false))
                    }
                }
            } message: {
                Text("This removes the selected titles and all their versions from your library. Files stay on disk.")
            }
    }

    private func selectionMenu(_ count: Int) -> some View {
        Menu {
            Section("\(count) selected · of \(visibleIds.count) filtered") {
                Button("Select all \(visibleIds.count)", systemImage: "checklist.checked") {
                    model.selection = Set(visibleIds)
                }
                .disabled(visibleIds.isEmpty || count >= visibleIds.count)
                Button("Clear", systemImage: "xmark.circle") { model.selection = [] }
                    .disabled(count == 0)
            }
        } label: {
            Label("Selection", systemImage: "checklist")
        }
        .accessibilityValue("\(count) selected")
    }

    private func actionsMenu(_ count: Int) -> some View {
        Menu {
            Button("Monitor", systemImage: "bookmark") {
                model.bulk(nil, "Couldn't update the selection") { client, ids in
                    try await client.bulkMonitor(BulkMonitorRequest(itemIds: ids, monitored: true))
                }
            }
            Button("Unmonitor", systemImage: "bookmark.slash") {
                model.bulk(nil, "Couldn't update the selection") { client, ids in
                    try await client.bulkMonitor(BulkMonitorRequest(itemIds: ids, monitored: false))
                }
            }
            Button("Refresh & Scan", systemImage: "arrow.clockwise") {
                model.bulk("Queued Refresh & Scan for \(count) \(count == 1 ? "item" : "items")",
                           "Couldn't queue the refresh") { client, ids in
                    try await client.bulkRefresh(BulkRefreshRequest(itemIds: ids, metadataOnly: false))
                }
            }
            Menu {
                ForEach(profiles) { profile in
                    Button(profile.name) {
                        model.bulk(nil, "Couldn't set the quality profile") { client, ids in
                            try await client.bulkQualityProfile(BulkQualityProfileRequest(itemIds: ids, qualityProfileId: profile.id))
                        }
                    }
                }
            } label: { Label("Quality Profile", systemImage: "slider.horizontal.3") }
            Menu {
                ForEach(AvailabilityOption.allCases, id: \.self) { option in
                    Button(option.label) { setAvailability(option) }
                }
            } label: { Label("Minimum availability", systemImage: "calendar") }
            Button("Change root…", systemImage: "folder") { showingRoot = true }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        } label: {
            Label("Actions", systemImage: "square.stack.3d.up")
        }
        .badge(count)
        .disabled(count == 0)
        .accessibilityLabel("Actions for \(count) selected")
    }

    private func setAvailability(_ option: AvailabilityOption) {
        let ids = Array(model.selection)
        guard let client = model.client else { return }
        Task {
            do {
                let result = try await client.bulkMinimumAvailability(
                    BulkMinimumAvailabilityRequest(itemIds: ids, minimumAvailability: option))
                let n = result.affected ?? ids.count
                model.toast("Set minimum availability on \(n) \(n == 1 ? "movie" : "movies")")
                model.exitSelectMode()
                await model.loadLibrary()
            } catch {
                model.toast("Couldn't set minimum availability", variant: .error)
            }
        }
    }
}

extension View {
    /// Library select mode's system bottom bar (`LibrarySelectBar`).
    func librarySelectBar(active: Bool, visibleIds: [Int]) -> some View {
        modifier(LibrarySelectBar(active: active, visibleIds: visibleIds))
    }
}
