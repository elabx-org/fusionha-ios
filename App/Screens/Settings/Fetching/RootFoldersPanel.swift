import SwiftUI
import FusionhaKit

/// Settings → Root Folders (`RootFoldersPanel.tsx`): a summary strip, one card per
/// root (path + tier/kind chips, Online/Offline, import mode, a pressure-aware
/// disk bar, the tracked footprint), a star to pin the root as the Add default
/// for its kind × tier, and an add/edit sheet (path + import mode).
struct RootFoldersPanel: View {
    @Environment(AppModel.self) private var model
    @State private var folders: [RootFolderInfo] = []
    @State private var defaults: [AddDefaultSlot]?
    @State private var loaded = false
    @State private var error: String?
    @State private var savingDefault = false
    @State private var editing: RootFolderInfo?
    @State private var adding = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    var body: some View {
        FetchingPage(slug: "roots", toaster: toaster, confirm: $confirm, refresh: load) {
            HStack {
                Spacer()
                Button("+ Add root folder") { adding = true }.buttonStyle(.web())
            }
            .padding(.bottom, 14)

            metrics.padding(.bottom, 16)

            if !loaded || error != nil {
                FetchLoading(error: error)
            }
            VStack(spacing: 11) {
                ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                    RootFolderCard(folder: folder,
                                   defaultsReady: defaults != nil,
                                   saving: savingDefault,
                                   onToggleDefault: { on in toggleDefault(folder, on) },
                                   onEdit: { editing = folder },
                                   onDelete: { askDelete(folder) })
                        .fetchReveal(index)
                }
            }
            .padding(.bottom, 12)

            FetchDashedAddButton(title: "+ Add a root folder") { adding = true }
        }
        .task { await load() }
        .sheet(isPresented: $adding) {
            RootFolderSheet(folder: nil) { await load() }
        }
        .sheet(item: $editing) { folder in
            RootFolderSheet(folder: folder) { await load() }
        }
    }

    // MARK: Summary strip

    private var metrics: some View {
        let total = folders.compactMap(\.totalSpace).reduce(0, +)
        let free = folders.compactMap(\.freeSpace).reduce(0, +)
        let tracked = folders.compactMap(\.trackedEditions).reduce(0, +)
        let trackedBytes = folders.compactMap(\.trackedSize).reduce(0, +)
        let defaultsSet = folders.reduce(0) { $0 + ($1.defaultFor?.count ?? 0) }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
            RootStatTile(key: "Roots", value: "\(folders.count)", sub: "quality tiers", tint: Theme.grab)
                .fetchReveal(0)
            RootStatTile(key: "Storage", value: total > 0 ? FetchFormat.bytes(total) : "—",
                         sub: free > 0 ? "\(FetchFormat.bytes(free)) free" : "unreported", tint: Theme.grab)
                .fetchReveal(1)
            RootStatTile(key: "Tracked here", value: FetchFormat.grouped(tracked),
                         sub: "versions · \(FetchFormat.bytes(trackedBytes))", tint: Theme.grab)
                .fetchReveal(2)
            RootStatTile(key: "Auto-op defaults", value: "\(defaultsSet) / 6", sub: "auto-op roots", tint: Theme.done)
                .fetchReveal(3)
        }
    }

    // MARK: Actions

    private func load() async {
        guard let client = model.client else { return }
        do {
            async let roots = client.rootFolderDetails()
            async let slots = try? client.addDefaults()
            folders = try await roots
            defaults = await slots
            error = nil
        } catch {
            self.error = error.settingsMessage
        }
        loaded = true
    }

    /// Pins (or clears) this root as the Add default for its inferred kind × tier,
    /// keeping that slot's quality profile untouched (it's owned by Default Profiles).
    private func toggleDefault(_ folder: RootFolderInfo, _ on: Bool) {
        guard let client = model.client else { return }
        let kind = folder.inferredKind
        let tier = folder.inferredTier
        let current = defaults?.first { $0.profileKind == kind && $0.tier == tier }
        let slot = AddDefaultSlot(kind: kind, tier: tier,
                                  profileId: current?.qualityProfileId,
                                  rootId: on ? folder.id : nil)
        savingDefault = true
        Task {
            do {
                try await client.saveAddDefaults([slot])
                await load()
            } catch {
                toaster.error(error, title: "Could not update the default")
            }
            savingDefault = false
        }
    }

    private func askDelete(_ folder: RootFolderInfo) {
        confirm = FetchConfirm(
            title: "Delete \(folder.path)?",
            message: "fusionha stops using this root folder. Files on disk are not touched.") {
            Task {
                guard let client = model.client else { return }
                do {
                    try await client.configDelete(.rootFolders, id: folder.id)
                    await load()
                } catch {
                    toaster.error(error, title: "Could not delete the root folder")
                }
            }
        }
    }
}

/// One stat tile of the summary strip, with the web's ambient colour wash.
private struct RootStatTile: View {
    let key: String
    let value: String
    let sub: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(key.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Theme.mut)
            Text(value)
                .font(.system(size: 18, weight: .heavy).monospacedDigit())
                .tracking(-0.5)
                .foregroundStyle(Theme.txt)
                .padding(.top, 4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(sub)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.mut)
                .padding(.top, 2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [tint.opacity(0.14), tint.opacity(0)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }
}
