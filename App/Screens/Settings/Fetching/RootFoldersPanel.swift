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
                .font(.system(size: 10.5, weight: .semibold))
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
                .font(.system(size: 10.5, design: .monospaced))
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

/// One root's card, stacked like the web's mobile layout: identity, usage, actions.
private struct RootFolderCard: View {
    let folder: RootFolderInfo
    let defaultsReady: Bool
    let saving: Bool
    let onToggleDefault: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private static let kindLabel = ["movie": "Movies", "series": "Series", "anime": "Anime"]

    private var kindLabel: String { Self.kindLabel[folder.inferredKind] ?? "Movies" }
    private var isDefaultHere: Bool {
        folder.defaultFor?.contains { $0.profileKind == folder.inferredKind && $0.tier == folder.inferredTier } == true
    }
    private var pct: Int? {
        guard let total = folder.totalSpace, total > 0, let used = folder.usedSpace else { return nil }
        return min(100, Int((Double(used) / Double(total) * 100).rounded()))
    }
    private var editions: Int { folder.trackedEditions ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 17))
                    .foregroundStyle(folder.online ? Theme.mut : Theme.stuck)
                    .frame(width: 42, height: 42)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
                VStack(alignment: .leading, spacing: 8) {
                    FetchFlow(spacing: 8, lineSpacing: 6) {
                        Text(folder.path)
                            .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        FetchTierChip(tier: folder.inferredTier)
                        FetchChip(text: kindLabel)
                        ForEach(folder.defaultFor ?? [], id: \.self) { slot in
                            Text("Default · \(Self.kindLabel[slot.profileKind] ?? slot.profileKind) · \(slot.tier.pill)".uppercased())
                                .font(.system(size: 9.5, weight: .heavy))
                                .tracking(0.2)
                                .foregroundStyle(Theme.done)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Theme.done.opacity(0.14), in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.done.opacity(0.36)))
                                .fixedSize()
                        }
                    }
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(folder.online ? Theme.done : Theme.stuck)
                                .frame(width: 7, height: 7)
                                .background(Circle().fill((folder.online ? Theme.done : Theme.stuck).opacity(0.16)).padding(-3))
                            Text(folder.online ? "Online" : "Offline · not reachable")
                                .font(.system(size: 11))
                                .foregroundStyle(folder.online ? Theme.mut : Theme.stuck)
                        }
                        Text(folder.importMode.label)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.line))
                    }
                }
            }

            usage

            HStack(spacing: 7) {
                Spacer()
                actionButton(systemName: isDefaultHere ? "star.fill" : "star",
                             label: isDefaultHere ? "Clear default for \(kindLabel) · \(folder.inferredTier.pill)"
                                : "Set \(folder.path) as default for \(kindLabel) · \(folder.inferredTier.pill)",
                             tint: isDefaultHere ? Theme.done : Theme.dim, highlighted: isDefaultHere) {
                    onToggleDefault(!isDefaultHere)
                }
                .disabled(!defaultsReady || saving)
                actionButton(systemName: "pencil", label: "Edit \(folder.path)", action: onEdit)
                actionButton(systemName: "trash", label: "Delete \(folder.path)", tint: Theme.danger.opacity(0.85), action: onDelete)
            }
        }
        .fetchCard(padding: 13, radius: 14, border: folder.online ? Theme.line : Theme.stuck.opacity(0.4))
    }

    @ViewBuilder
    private var usage: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if !folder.online {
                    Text("Mount not responding").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.stuck)
                    Spacer(minLength: 4)
                    mono("\(editions) versions")
                } else if let total = folder.totalSpace, let used = folder.usedSpace {
                    Text(FetchFormat.bytes(used)).font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                    Text("used").font(.system(size: 12)).foregroundStyle(Theme.txt)
                    Spacer(minLength: 4)
                    mono((folder.freeSpace.map { "\(FetchFormat.bytes($0)) free · " } ?? "") + FetchFormat.bytes(total))
                } else {
                    Text("—").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.txt)
                    Text("size not reported").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    Spacer(minLength: 4)
                    mono("\(editions) versions")
                }
            }
            .padding(.bottom, 7)

            diskBar

            HStack {
                if folder.online, let pct {
                    Text("\(editions) \(editions == 1 ? "version" : "versions") tracked here\(pct >= 90 ? " · running low" : "")")
                    Spacer()
                    Text("\(pct)%").foregroundStyle(pct >= 75 ? Theme.miss : Theme.dim)
                } else if folder.online {
                    Text("symlinks → mount target")
                    Spacer()
                } else {
                    Text("files show as not-found until it returns").foregroundStyle(Theme.stuck)
                    Spacer()
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.dim)
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var diskBar: some View {
        if !folder.online {
            FetchBar(fraction: 1, color: Theme.stuck.opacity(0.22))
        } else if let pct {
            FetchBar(fraction: max(4, Double(pct)) / 100,
                     color: pct >= 90 ? Theme.stuck : pct >= 75 ? Theme.miss : Theme.grab)
        } else {
            // Unreported mount → hatched, never a fake percentage.
            Capsule()
                .fill(Color.white.opacity(0.07))
                .overlay(
                    HStack(spacing: 6) {
                        ForEach(0..<60, id: \.self) { _ in
                            Rectangle().fill(Theme.grab.opacity(0.35)).frame(width: 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                )
                .clipShape(Capsule())
                .frame(height: 8)
        }
    }

    private func mono(_ text: String) -> some View {
        Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut).lineLimit(1)
    }

    private func actionButton(systemName: String, label: String, tint: Color = Theme.dim,
                              highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(highlighted ? Theme.done.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(highlighted ? Theme.done.opacity(0.4) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Add / edit a root folder: a path plus its import mode.
private struct RootFolderSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let folder: RootFolderInfo?
    let onSaved: () async -> Void
    @State private var path: String
    @State private var mode: ImportMode
    @State private var saving = false
    @State private var error: String?

    init(folder: RootFolderInfo?, onSaved: @escaping () async -> Void) {
        self.folder = folder
        self.onSaved = onSaved
        _path = State(initialValue: folder?.path ?? "")
        _mode = State(initialValue: folder?.importMode ?? .hardlink)
    }

    private var trimmed: String { path.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        FetchFormSheet(title: folder == nil ? "Add root folder" : "Edit root folder",
                       canSave: !trimmed.isEmpty, saving: saving,
                       onCancel: { dismiss() }, onSave: save) {
            SettingsSection {
                FetchTextRow(label: "Path", text: $path, prompt: "/movies-4k", mono: true)
                Picker(selection: $mode) {
                    ForEach(ImportMode.allCases) { Text($0.label).tag($0) }
                } label: {
                    FieldLabel(label: "Import mode",
                               description: "Hardlink falls back to copy across filesystems; symlink suits debrid/rclone mounts.")
                }
                .pickerStyle(.menu)
                .tint(Theme.mut)
            }
            if let error {
                Section { Label(error, systemImage: "xmark").font(.system(size: 12.5)).foregroundStyle(Theme.danger) }
                    .listRowBackground(Theme.card)
            }
        }
    }

    private func save() {
        guard let client = model.client, !trimmed.isEmpty else { return }
        let body: SettingsJSON = ["path": .string(trimmed), "default_import_mode": .string(mode.rawValue)]
        saving = true
        Task {
            do {
                if let folder {
                    try await client.configUpdate(.rootFolders, id: folder.id, body)
                } else {
                    try await client.configCreate(.rootFolders, body)
                }
                await onSaved()
                dismiss()
            } catch {
                self.error = error.settingsMessage
            }
            saving = false
        }
    }
}
