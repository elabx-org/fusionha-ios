import SwiftUI
import FusionhaKit

// MARK: - Bulk action bar (BulkActionBar.tsx)

/// The glass bar that replaces the tab bar in select mode: the count, "of N
/// filtered", Select all / Clear / Done, and the bulk actions once something
/// is selected.
struct BulkActionBar: View {
    @Environment(AppModel.self) private var model
    let visibleIds: [Int]
    @State private var profiles: [QualityProfile] = []
    @State private var showingRoot = false
    @State private var confirmingDelete = false

    var body: some View {
        let count = model.selection.count
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(count) selected").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                if !visibleIds.isEmpty {
                    Text("of \(visibleIds.count) filtered").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if !visibleIds.isEmpty && count < visibleIds.count {
                    ghost("Select all \(visibleIds.count)") { model.selection = Set(visibleIds) }
                }
                if count > 0 { ghost("Clear") { model.selection = [] } }
                ghost("Done", strong: true) { model.exitSelectMode() }
            }
            if count > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        action("Monitor", "bookmark") {
                            model.bulk(nil, "Couldn't update the selection") { client, ids in
                                try await client.bulkMonitor(BulkMonitorRequest(itemIds: ids, monitored: true))
                            }
                        }
                        action("Unmonitor", "bookmark.slash") {
                            model.bulk(nil, "Couldn't update the selection") { client, ids in
                                try await client.bulkMonitor(BulkMonitorRequest(itemIds: ids, monitored: false))
                            }
                        }
                        action("Refresh & Scan", "arrow.clockwise") {
                            let n = count
                            model.bulk("Queued Refresh & Scan for \(n) \(n == 1 ? "item" : "items")", "Couldn't queue the refresh") { client, ids in
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
                        } label: { chip("Quality Profile", "slider.horizontal.3", menu: true) }
                        Menu {
                            ForEach(AvailabilityOption.allCases, id: \.self) { option in
                                Button(option.label) { setAvailability(option) }
                            }
                        } label: { chip("Minimum availability", "calendar", menu: true) }
                        action("Change root…", "folder") { showingRoot = true }
                        Button { confirmingDelete = true } label: {
                            chip("Delete", "trash", danger: true)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .scrollClipDisabled()
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 11)
        .padding(.bottom, 11)
        .background {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .ignoresSafeArea(edges: .bottom)
        }
        .task { profiles = (try? await model.client?.qualityProfiles()) ?? [] }
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

    private func ghost(_ title: String, strong: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: strong ? .bold : .semibold))
                .foregroundStyle(strong ? Theme.i2 : Theme.txt)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 9)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
    }

    private func action(_ title: String, _ symbol: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { chip(title, symbol) }
            .buttonStyle(PressScaleStyle())
    }

    private func chip(_ title: String, _ symbol: String, menu: Bool = false, danger: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
            Text(title).font(.system(size: 12.5, weight: .semibold))
            if menu { Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut) }
        }
        .foregroundStyle(danger ? Theme.danger : Theme.txt)
        .padding(.horizontal, 11)
        .frame(height: 32)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// ChangeRootPopover: re-assign the selection's root folder per tier.
private struct ChangeRootSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// HD·1080p by default: "Every version" collapses the tiers onto one root.
    @State private var tier = "HD-1080p"
    @State private var roots: [RootFolder] = []
    @State private var rootId: Int?
    @State private var disposition: RootFileDisposition = .move

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Re-assign root folder").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
            field("Which versions to move") {
                SegmentedPills(options: [("HD-1080p", "HD·1080p"), ("UHD-2160p", "UHD·4K"), ("all", "Every version")],
                               selection: $tier, fill: true)
                if tier == "all" {
                    warning("This collapses HD·1080p, UHD·4K and every edition onto one root, so the tier separation is lost. Prefer scoping to one tier.", Theme.miss)
                }
            }
            field("New root folder") {
                Picker("New root folder", selection: $rootId) {
                    Text("Choose…").tag(Int?.none)
                    ForEach(roots) { Text($0.path).tag(Int?.some($0.id)) }
                }
                .pickerStyle(.menu)
                .tint(Theme.txt)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .panel(Theme.panel2, radius: 10)
            }
            field("Existing files") {
                SegmentedPills(options: RootFileDisposition.allCases.map { ($0, $0.label) }, selection: $disposition, fill: true)
                if disposition == .delete {
                    warning("The existing files are permanently deleted.", Theme.danger)
                } else if disposition == .leave {
                    warning("Files stay in the old folder. Those versions show as Missing until moved or re-imported.", Theme.miss)
                }
            }
            Spacer(minLength: 0)
            Button {
                guard let rootId else { return }
                let tier = self.tier, disposition = self.disposition
                model.bulk("Root folder updated", "Couldn't change the root folder") { client, ids in
                    try await client.bulkRootFolder(BulkRootFolderRequest(itemIds: ids, tier: tier, rootFolderId: rootId,
                                                                          disposition: disposition))
                }
                dismiss()
            } label: {
                Text("Apply")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.primary, in: Capsule())
            }
            .buttonStyle(PressScaleStyle())
            .disabled(rootId == nil)
            .opacity(rootId == nil ? 0.5 : 1)
        }
        .padding(20)
        .task { roots = (try? await model.client?.rootFolders()) ?? [] }
    }

    private func warning(_ text: String, _ tone: Color) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.txt)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .actWash(tone, radius: 10, base: Theme.panel2)
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
            content()
        }
    }
}
