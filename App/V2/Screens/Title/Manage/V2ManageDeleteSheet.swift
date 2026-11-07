import SwiftUI
import FusionhaKit

/// What a Delete asks about: the files, what they free and where they sit.
struct V2ManageDeleteTarget: Identifiable {
    let items: [ManagedFileItem]
    let summary: ManageSelectionSummary
    let message: String
    /// What "Stop monitoring" reaches beyond these files, and its default.
    let impact: ManageMonitorImpact
    /// The other monitored versions, named ("UHD·4K").
    let otherVersions: [String]
    var id: [Int] { items.map(\.id) }

    @MainActor init(items: [ManagedFileItem], groups: [ManageSeasonGroup], model: ManageFilesModel) {
        let detail = model.detail
        self.items = items
        summary = ManageEpisodes.summary(Set(items.map(\.id)), groups: groups)
        message = ManageEpisodes.deleteMessage(summary, title: detail.title)
        impact = ManageEpisodes.monitorImpact(detail: detail, allRows: model.allRows, deleting: items)
        otherVersions = impact.otherVersionIds.compactMap { id in
            detail.editions.first { $0.id == id }.map { model.versionName($0) }
        }
    }

    var toggleLabel: String {
        impact.multiVersion ? "Stop monitoring these episodes in every version" : "Stop monitoring these episodes"
    }

    /// "UHD·4K will stop searching for them as well."
    var otherVersionsNote: String? {
        otherVersions.isEmpty ? nil : "\(otherVersions.joined(separator: " and ")) will stop searching for them as well."
    }

    var title: String { items.count == 1 ? "Delete 1 file?" : "Delete \(items.count) files?" }
    var action: String { items.count == 1 ? "Delete 1 file" : "Delete \(items.count) files" }
}

/// The clear-out confirmation (mock frame 3): what goes and what it frees,
/// the one real decision (stop monitoring: on by default, off when another
/// version still has or wants these episodes), then Cancel and
/// the red Delete. It stays up while the delete runs and shows a failure in
/// place; on success it closes and the title reloads.
struct V2ManageDeleteSheet: View {
    let model: ManageFilesModel
    let target: V2ManageDeleteTarget
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pagePalette) private var page
    @State private var stopMonitoring: Bool
    @State private var running = false
    @State private var failure: String?

    init(model: ManageFilesModel, target: V2ManageDeleteTarget) {
        self.model = model
        self.target = target
        _stopMonitoring = State(initialValue: target.impact.defaultStop)
    }

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(target.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ink)
                Text(target.message)
                    .font(.system(size: 14.5))
                    .foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                toggle
                if let failure {
                    Label(failure, systemImage: "exclamationmark.circle")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.dangerText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                buttons
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(running)
    }

    private var toggle: some View {
        Toggle(isOn: $stopMonitoring) {
            VStack(alignment: .leading, spacing: 3) {
                Text(target.toggleLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = target.otherVersionsNote {
                    Text(note)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("On: fusionha won’t download them again. Off: they become Wanted and are searched for.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.primary)
        .disabled(running)
        .padding(14)
        .background { ModuleSurface(radius: 16) }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("Cancel").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .disabled(running)
            Button(role: .destructive) { Task { await run() } } label: {
                HStack(spacing: 8) {
                    if running { ProgressView().tint(Theme.onDanger) }
                    Text(running ? "Deleting…" : target.action)
                }
                .foregroundStyle(Theme.onDanger)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.danger)
            .disabled(running)
        }
        .font(.system(size: 15.5, weight: .semibold))
    }

    private func run() async {
        running = true
        failure = nil
        let problem = await model.clearOut(target.items, stopMonitoring: stopMonitoring)
        await store.reload()
        running = false
        if let problem { failure = problem } else { dismiss() }
    }
}
