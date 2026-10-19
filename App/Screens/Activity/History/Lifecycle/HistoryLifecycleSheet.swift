import SwiftUI
import FusionhaKit

/// A story's lifecycle (web `LifecyclePanel` in the phone sheet): header with
/// the title, episode code, tier chip and actions; the HD/4K switch; then every
/// History event of that episode or movie version, oldest first, with failed
/// steps in plain words and HELD steps expanded (`HeldStep`).
struct HistoryLifecycleSheet: View {
    let story: HistoryStory
    var onChanged: () -> Void = {}
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toaster = ActToaster()
    @State private var picked: Int?
    @State private var lane: [HistoryEntry]?
    @State private var siblings: [HistoryEntry] = []
    @State private var blocks: [ReleaseGroupBlock] = []
    @State private var error: String?

    /// The narrowest scope the story pins down (web `storyLifecycleScope`).
    private var episodeId: Int? { story.events.first { $0.episodeId != nil }?.episodeId }
    private var scopeVersionId: Int? { story.events.first { $0.editionId != nil }?.editionId }
    private var activeVersionId: Int? { picked ?? scopeVersionId }

    private var events: [HistoryEntry] {
        HistoryLifecycleModel.events(lane ?? [], versionId: activeVersionId, episodeId: episodeId)
    }

    private var versions: [HistoryLifecycleModel.Version] {
        HistoryLifecycleModel.switchVersions(events + siblings, activeId: activeVersionId, fallbackTier: story.tier)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LifecycleHeader(story: story, tier: versions.first?.tier ?? story.tier,
                                    versionId: activeVersionId, episodeId: episodeId, onChanged: onChanged)
                    if versions.count > 1, let active = activeVersionId {
                        LifecycleVersionSwitch(versions: versions, activeId: active) { picked = $0 }
                    }
                    content.id(activeVersionId)
                        .transition(.opacity)
                }
                .padding(16)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: activeVersionId)
            }
            .background(Theme.bg)
            .navigationTitle("Lifecycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } } }
            .closeOnlyBars()
            .task(id: activeVersionId) { await load() }
        }
        .overlay { ActToastOverlay(toaster: toaster) }
        .environment(toaster)
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var content: some View {
        if let error {
            VStack(alignment: .leading, spacing: 10) {
                Text(error).font(.system(size: 14)).foregroundStyle(Theme.mut)
                Button("Try again") { Task { await load() } }.buttonStyle(ActButtonStyle(kind: .ghost))
            }
        } else if lane == nil {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
                .accessibilityLabel("Loading lifecycle")
        } else if events.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("No history yet").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                Text("Grabs, imports and upgrades for this version will appear here.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                let last = events.count - 1
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    LifecycleStepRow(event: event, last: index == last, itemTitle: story.title,
                                     groupBlock: LifecycleStepRow.block(for: event, in: blocks))
                }
            }
        }
    }

    private func load() async {
        guard let client = model.client, let itemId = story.mediaItemId else { return }
        error = nil
        do {
            let page = try await client.historyLifecycle(itemId: itemId, episodeId: episodeId, versionId: activeVersionId)
            lane = page.items.sorted { $0.createdAt < $1.createdAt }
        } catch let e as APIError where e.status == 404 {
            error = "This title is no longer in your library."
            return
        } catch {
            self.error = "The lifecycle could not be loaded. Check the backend and try again."
            return
        }
        // Lazy: the sibling tier(s) of the same episode / movie for the HD/4K switch.
        if siblings.isEmpty, let all = try? await client.historyLifecycle(itemId: itemId, episodeId: episodeId, versionId: nil) {
            siblings = all.items
        }
        // One blocks read, only when a HELD step will use it (integrations.manage).
        if events.contains(where: { $0.eventType == "HELD" }), model.me?.hasPermission("integrations.manage") == true,
           let all = try? await client.releaseGroupBlocks() {
            blocks = all
        }
    }
}

/// The small HD / 4K switch (web `LifecycleVersionSwitch`): view the other version's lane.
struct LifecycleVersionSwitch: View {
    let versions: [HistoryLifecycleModel.Version]
    let activeId: Int
    let onPick: (Int) -> Void

    var body: some View {
        let ordered = versions.sorted { $0.tier == $1.tier ? $0.id < $1.id : $0.tier == .hd }
        HStack(spacing: 8) {
            ForEach(ordered, id: \.id) { v in
                let on = v.id == activeId
                Button { onPick(v.id) } label: {
                    Text(v.tier == .hd ? "HD" : "4K")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(on ? Theme.tierFill(v.tier) : Theme.mut)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassControl(on: on)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Version")
    }
}
