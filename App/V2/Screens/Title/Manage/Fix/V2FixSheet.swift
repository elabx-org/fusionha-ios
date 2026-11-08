import SwiftUI
import FusionhaKit

/// Needs you's Fix mode (owner-approved mock, 2026-11-08): Review on a
/// version that needs you opens this instead of the clear-out sheet. "Fix HD"
/// with "Title · n problems", one card saying what is wrong and the best
/// fix, only the problem files (each with its reason in orange), "n other
/// files are fine · Show", and a glass bar that leads with the recommended
/// fix. Reuses v1's `ManageFilesModel`; series and movies alike.
struct V2FixSheet: View {
    @State private var model: ManageFilesModel
    @Environment(AppModel.self) private var app
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let showAll: () -> Void
    @State private var editing: ManageFilesEditTarget?
    @State private var deleting: V2ManageDeleteTarget?
    @State private var confirm: ManageFilesConfirm?
    @State private var replacing: V2FixReplaceTarget?
    @State private var picking: InteractiveTarget?
    @State private var searching = false

    init(detail: ItemDetail, target: ManageFilesTarget, showAll: @escaping () -> Void) {
        _model = State(initialValue: ManageFilesModel(detail: detail, scopeVersionIds: target.versionIds, season: target.season,
                                                        selectsProblems: true))
        self.showAll = showAll
    }

    private var detail: ItemDetail { model.detail }
    private var art: URL? { PageArtSource.url(backdrop: detail.backdropUrl, poster: detail.posterUrl) }
    private var edition: DetailEdition? { detail.editions.first { model.scopeVersionIds?.contains($0.id) == true } }
    private var problems: [ManagedFileItem] { model.problemItems }
    /// One problem is always the target; with several, the ticked ones.
    private var targets: [ManagedFileItem] {
        problems.count == 1 ? problems : problems.filter { model.selected.contains($0.id) }
    }
    private var lines: [ManageEpisodeLine] { ManageEpisodes.groups(problems, detail: detail).flatMap(\.lines) }
    private var title: String { edition.map { "Fix \($0.tier.badgeLetters)" } ?? "Fix files" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) { content }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable { await model.load() }
            .safeAreaInset(edge: .bottom, spacing: 0) { bar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { fixToolbar }
            .v2PageGround(art: art)
            .sheet(item: $editing) { t in ManageFileEditSheet(model: model, targets: t.items).sheetEscapeRoot() }
            .sheet(item: $deleting) { t in
                V2ManageDeleteSheet(model: model, target: t)
                    .environment(store)
                    .v2PageGround(art: art)
            }
            .sheet(item: $replacing) { t in
                V2FixReplaceSheet(model: model, target: t, onStarted: { dismiss() })
                    .environment(app)
                    .environment(store)
                    .v2PageGround(art: art)
            }
            .sheet(item: $picking) { t in
                V2InteractiveSearchSheet(target: t)
                    .environment(store)
            }
            .confirmationDialog(confirm?.title(model) ?? "", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                                titleVisibility: .visible, presenting: confirm) { c in
                V2ManageRowConfirmButtons(model: model, confirm: c)
            } message: { c in
                if let m = c.message { Text(m) }
            }
        }
        .task {
            model.client = app.client
            await model.load()
        }
        .onChange(of: model.items) { _, _ in
            // An action clears the selection; the files still wrong stay the targets.
            if model.selected.isEmpty { model.selected = Set(model.problemItems.map(\.id)) }
        }
        .onDisappear { if model.changed { Task { await store.reload() } } }
        .retainsDraft("manage.fix.model", $model)
    }

    @ToolbarContentBuilder private var fixToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(title).font(.system(size: 17, weight: .bold))
                Text(model.loaded && problems.isEmpty ? "\(detail.title) · nothing to fix"
                     : ManageFix.subtitle(title: detail.title, count: problems.count))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .closeOnEscape(true)
        }
    }

    @ViewBuilder private var content: some View {
        if let note = model.note { V2FixNoteLine(note: note) }
        if !model.loaded {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
        } else if model.loadFailed && model.items.isEmpty {
            V2FixMessage(text: "Couldn’t load this title’s files. Pull to try again.", action: nil)
        } else if problems.isEmpty {
            V2FixMessage(text: "Nothing needs fixing here now.", action: (title: "Show all files", run: showAll))
        } else {
            V2FixProblemCard(tier: edition?.tier, groups: ManageFix.groups(problems),
                             name: detail.isSeries ? lines.first?.title : detail.title)
            rows
            if let others = ManageFix.othersLine(problems: problems, all: model.items) {
                V2FixOthersLine(text: others, show: showAll)
            }
        }
    }

    private var rows: some View {
        let all = lines
        return VStack(spacing: 0) {
            ForEach(Array(all.enumerated()), id: \.element.id) { i, line in
                if i > 0 {
                    Rectangle()
                        .fill(ModuleMetrics.hairline(light: Theme.isLight))
                        .frame(height: 0.5)
                        .padding(.leading, all.count > 1 ? 52 : 16)
                }
                V2FixFileRow(model: model, line: line, selectable: all.count > 1,
                             edit: { editing = ManageFilesEditTarget(items: [line.item]) })
            }
        }
        .background { ModuleSurface(radius: 20) }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder private var bar: some View {
        if let n = model.deleting {
            V2ManageProgressBar(text: "Deleting \(n == 1 ? "1 file" : "\(n) files")…")
        } else if model.loaded, !problems.isEmpty {
            V2FixBar(count: targets.count, showsCount: problems.count > 1,
                     action: ManageFix.primary(targets.isEmpty ? problems : targets),
                     busy: model.busy || model.rescanning || searching, picks: picks,
                     primary: { openReplace(forceBlocklist: false) },
                     search: { Task { await autoSearch() } },
                     pick: { p in picking = InteractiveTarget(editionIds: [p.editionId], episodeId: p.episodeId, subtitle: p.label) },
                     menu: menuActions)
        }
    }

    // MARK: Actions

    /// The targets the release picker and the episode search reach.
    private var picks: [V2FixPick] {
        let ids = Set(targets.map(\.id))
        return lines.filter { ids.contains($0.id) }.compactMap { line in
            let item = line.item
            if detail.isSeries {
                guard let ep = ManageEpisodes.episodeIds([item], detail: detail).first else { return nil }
                let label = [line.code, line.title].compactMap { $0 }.joined(separator: " ")
                return V2FixPick(id: item.id, label: label, editionId: item.row.versionId, episodeId: ep)
            }
            return V2FixPick(id: item.id, label: edition?.label ?? detail.title, editionId: item.row.versionId, episodeId: nil)
        }
    }

    private var menuActions: V2FixMenuActions {
        V2FixMenuActions(
            blocklistAndSearch: { openReplace(forceBlocklist: true) },
            recheck: {
                let seasons = Set(targets.compactMap(\.row.season))
                Task { await model.rescan(season: seasons.count == 1 ? seasons.first : nil) }
            },
            edit: { editing = ManageFilesEditTarget(items: targets) },
            stopMonitoring: { Task { await stopMonitoring() } },
            delete: {
                if detail.isSeries {
                    deleting = V2ManageDeleteTarget(items: targets, groups: ManageEpisodes.groups(model.items, detail: detail),
                                                    model: model)
                } else {
                    confirm = .delete(targets)
                }
            }
        )
    }

    private func openReplace(forceBlocklist: Bool) {
        let items = targets
        guard !items.isEmpty else { return }
        let damaged = items.filter(\.unreadable)
        let name = items.count == 1 ? (detail.isSeries ? lines.first { $0.id == items[0].id }?.title : detail.title) : nil
        replacing = V2FixReplaceTarget(
            items: items, action: forceBlocklist ? .replace : ManageFix.primary(items), name: name,
            blocklistByDefault: forceBlocklist || ManageFix.blocklistByDefault(items),
            candidates: forceBlocklist || damaged.isEmpty ? items : damaged)
    }

    /// Automatic search per problem episode (or the movie's version); the
    /// current file stays until something better lands.
    private func autoSearch() async {
        guard let client = app.client else { return }
        searching = true
        defer { searching = false }
        var grabbed = 0, failed = 0
        for p in picks {
            do {
                let decisions = try await client.search(itemId: detail.id, editionId: p.editionId, episodeId: p.episodeId)
                grabbed += decisions.filter(\.grabbed).count
            } catch {
                failed += 1
            }
        }
        model.note = failed > 0
            ? ManageFilesModel.Note(text: "Couldn’t search \(failed == 1 ? "1 file" : "\(failed) files"). Try again.", failed: true)
            : ManageFilesModel.Note(text: grabbed > 0 ? "Searched. Grabbing \(grabbed == 1 ? "a release" : "\(grabbed) releases")."
                                    : "Searched. Nothing better found yet; the current file stays.", failed: false)
    }

    private func stopMonitoring() async {
        if detail.isSeries {
            await model.stopMonitoringEpisodes(targets)
        } else if let edition {
            await store.setEditionMonitored(edition, false)
            model.note = ManageFilesModel.Note(text: "Stopped monitoring \(model.versionName(edition)).", failed: false)
        }
    }
}
