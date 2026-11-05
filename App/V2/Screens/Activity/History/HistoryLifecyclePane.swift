import SwiftUI
import FusionhaKit

/// A story's lifecycle (mock activity-log.js `lifecycle`): the title, the
/// version and Open title; HD | 4K as a segmented picker; the version's
/// whole path on one W1 card (v1's steps, held steps included); then
/// Re-grab, Blocklist, Search again and the raw events. The open Duo's
/// right page; on the phone it sits in a sheet (`HistoryLifecycleSheetV2`).
struct HistoryLifecyclePane: View {
    let story: HistoryStory
    /// Open title in the header (the sheet keeps it in its bar).
    var showsOpenTitle = true
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var loader: HistoryLifecycleLoader
    @State private var actions = V2StoryActions()
    @State private var rawOpen = false

    init(story: HistoryStory, showsOpenTitle: Bool = true, onChanged: @escaping () -> Void) {
        self.story = story
        self.showsOpenTitle = showsOpenTitle
        self.onChanged = onChanged
        _loader = State(initialValue: HistoryLifecycleLoader(story: story))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            versionPicker
            steps
                .id(loader.activeVersionId)
                .transition(.opacity)
            actionRow
            if rawOpen { HistoryStoryDisclosure(story: story).v2CardStyle(padding: 0) }
        }
        .animation(motion ? .easeOut(duration: 0.2) : nil, value: loader.activeVersionId)
        .task(id: loader.activeVersionId) {
            await loader.load(client: model.client, canManage: model.me?.hasPermission("integrations.manage") == true)
        }
        .v2StoryActionSheets(actions, story: story, onChanged: onChanged)
    }

    private var header: some View {
        HStack(spacing: 12) {
            V2ScopeThumb(url: story.posterUrl, width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(story.title).font(.system(size: 19, weight: .bold)).foregroundStyle(page?.ink ?? Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
            Spacer(minLength: 8)
            if showsOpenTitle, let id = story.mediaItemId {
                V2CapsuleButton(title: "Open title", systemImage: "chevron.right") { model.open(id) }
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let code = HistoryLifecycleModel.episodeCode(story.episodeLabel) { parts.append(code) }
        if let tier = loader.activeTier { parts.append("\(tier.badgeLetters) version") }
        parts.append(ActFmt.relative(story.time))
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var versionPicker: some View {
        let versions = loader.versions
        if versions.count > 1, let active = loader.activeVersionId {
            Picker("Version", selection: Binding(get: { active }, set: { loader.picked = $0 })) {
                ForEach(versions, id: \.id) { Text($0.tier.badgeLetters).tag($0.id) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
    }

    @ViewBuilder
    private var steps: some View {
        if let error = loader.error {
            VStack(alignment: .leading, spacing: 10) {
                Text(error).font(.system(size: 14)).foregroundStyle(page?.inkMuted ?? Theme.mut)
                Button("Try again") {
                    Task { await loader.load(client: model.client, canManage: model.me?.hasPermission("integrations.manage") == true) }
                }
                .buttonStyle(.glass)
            }
        } else if !loader.loaded {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24).accessibilityLabel("Loading lifecycle")
        } else if loader.events.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("No history yet").font(.system(size: 14, weight: .semibold)).foregroundStyle(page?.ink ?? Theme.txt)
                Text("Grabs, imports and upgrades for this version will appear here.")
                    .font(.system(size: 13)).foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
        } else {
            let events = loader.events
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    LifecycleStepRow(event: event, last: index == events.count - 1, itemTitle: story.title,
                                     groupBlock: LifecycleStepRow.block(for: event, in: loader.blocks))
                }
            }
            .v2CardStyle()
        }
    }

    private var actionRow: some View {
        ActFlow(spacing: 8, lineSpacing: 8) {
            if V2StoryActions.grab(of: story) != nil {
                V2CapsuleButton(title: "Re-grab", systemImage: "arrow.clockwise", busy: actions.regrabbing) {
                    Task { await actions.regrab(story, override: false, client: model.client, toaster: toaster, done: onChanged) }
                }
            }
            if story.type.actions.blocklist {
                V2CapsuleButton(title: "Blocklist", systemImage: "nosign", busy: actions.blocking) {
                    actions.blocklistDialog = true
                }
                .disabled(story.actionEntry.blocklistTarget == nil)
                .opacity(story.actionEntry.blocklistTarget == nil ? 0.4 : 1)
            }
            if story.mediaItemId != nil {
                V2CapsuleButton(title: "Search again", systemImage: "magnifyingglass") {
                    actions.searchAgain(story, client: model.client, toaster: toaster)
                }
            }
            V2CapsuleButton(title: rawOpen ? "Hide raw events" : "Raw events",
                            systemImage: rawOpen ? "chevron.up" : "chevron.down") {
                withAnimation(motion ? .easeOut(duration: 0.2) : nil) { rawOpen.toggle() }
            }
        }
    }
}

/// The phone's lifecycle: the pane in a sheet on the story's ground, with
/// Open title and Done in the bar.
struct HistoryLifecycleSheetV2: View {
    let story: HistoryStory
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Its own toaster, so toasts show over the sheet (as v1's lifecycle sheet).
    @State private var toaster = ActToaster()

    var body: some View {
        NavigationStack {
            ScrollView {
                HistoryLifecyclePane(story: story, showsOpenTitle: false, onChanged: onChanged)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .navigationTitle("Lifecycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let id = story.mediaItemId {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Open title", systemImage: "arrow.up.right.square") {
                            dismiss()
                            model.open(id)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .v2PageGround(art: PageArtSource.url(backdrop: nil, poster: story.posterUrl))
        }
        .overlay { ActToastOverlay(toaster: toaster) }
        .environment(toaster)
        .presentationDetents([.medium, .large])
    }
}
