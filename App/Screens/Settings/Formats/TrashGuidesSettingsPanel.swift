import SwiftUI
import FusionhaKit

/// Settings › Quality › TRaSH Guides (web `TrashPanel`): the sync header
/// (guide freshness, auto-sync cadence, Sync now) over the four sections —
/// Custom Formats, Profiles, Overrides & Conflicts and Presets — which the web
/// shows as tabs and iOS pushes. The Media choice is shared across them.
struct TrashGuidesSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var store
    @State private var category: TrashCategory = .movie
    @State private var status: TrashStatus?
    @State private var counts: [TrashCategory: Int] = [:]
    @State private var profileCount: Int?
    @State private var conflictCount = 0
    @State private var syncing = false
    @State private var toaster = FetchToaster()

    private static let off = -1

    var body: some View {
        SettingsForm(slug: "trash") {
            syncSection
            Section {
                NavigationLink { TrashCatalogScreen(category: $category, counts: counts) } label: {
                    row("Custom Formats", count: counts[category], systemImage: "textformat")
                }
                NavigationLink { TrashProfilesScreen(category: $category, counts: counts) } label: {
                    row("Profiles", count: profileCount, systemImage: "viewfinder")
                }
                NavigationLink { TrashConflictsScreen() } label: {
                    row("Overrides & Conflicts", count: conflictCount > 0 ? conflictCount : nil,
                        systemImage: "exclamationmark.arrow.triangle.2.circlepath", warn: true)
                }
                NavigationLink { TrashPresetsScreen() } label: {
                    row("Presets", count: nil, systemImage: "shippingbox")
                }
            } header: {
                Text("TRaSH Guides sections").textCase(nil)
            }
            .listRowBackground(Theme.card)
        }
        .task { await load() }
        .task(id: category) { await loadProfileCount() }
        .refreshable { await load() }
        .fetchToasts(toaster)
    }

    private var syncSection: some View {
        Section {
            HStack(spacing: 8) {
                let synced = TrashText.synced(status?.lastSyncedAt)
                Circle().fill(synced == nil ? Theme.dim : Theme.done).frame(width: 7, height: 7)
                if let synced {
                    Text("Guide cached · synced **\(synced)**")
                } else {
                    Text("Guide not synced yet")
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.mut)
            Picker("Auto-sync", selection: autoSync) {
                Text("off").tag(Self.off)
                let options = TrashText.intervalOptions(current: interval)
                ForEach(options.indices, id: \.self) { i in
                    Text(options[i].label).tag(options[i].seconds)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.mut)
            .accessibilityLabel("Auto-sync interval")
            Button(syncing ? "Syncing…" : "Sync now", systemImage: "arrow.clockwise") { Task { await sync() } }
                .disabled(syncing)
                .symbolEffect(.rotate, isActive: syncing)
        }
        .listRowBackground(Theme.card)
    }

    private var interval: Int { store.int("trash_sync_interval_seconds", TrashText.defaultSyncInterval) }

    /// Off clears `trash_auto_sync`; a cadence turns it on and stores the interval.
    private var autoSync: Binding<Int> {
        Binding(get: { store.bool("trash_auto_sync") ? interval : Self.off },
                set: { next in
                    if next == Self.off {
                        store.save("trash_auto_sync", .bool(false))
                    } else {
                        store.save(["trash_auto_sync": .bool(true), "trash_sync_interval_seconds": .number(Double(next))])
                    }
                })
    }

    private func row(_ title: String, count: Int?, systemImage: String, warn: Bool = false) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if let count { FetchPill(text: "\(count)", tone: warn ? .warn : .off) }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        status = try? await client.trashStatus()
        for c in TrashCategory.allCases {
            if let catalog = try? await client.trashCatalog(c) { counts[c] = catalog.formats.count }
        }
        conflictCount = (try? await client.trashConflicts().conflicts.count) ?? 0
    }

    private func loadProfileCount() async {
        guard let client = model.client else { return }
        profileCount = (try? await client.trashGuides(category).profiles.count)
    }

    private func sync() async {
        guard let client = model.client else { return }
        syncing = true
        defer { syncing = false }
        do {
            try await client.trashSync()
            toaster.show("Guide synced")
            await load()
            await loadProfileCount()
        } catch { toaster.error(error, title: "Sync failed") }
    }
}
