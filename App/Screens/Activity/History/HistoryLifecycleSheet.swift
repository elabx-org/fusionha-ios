import SwiftUI
import FusionhaKit

/// A story's lifecycle (web `LifecycleDrawer`): every History event for its
/// title, narrowed to the episode and version the story pins down, oldest
/// first, so you can read a file's whole life: grabbed, held, imported,
/// upgraded, deleted. A season-pack grab carries no episode, so the scope
/// takes the first event that names one.
struct HistoryLifecycleSheet: View {
    let story: HistoryStory
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var events: [HistoryEntry]?
    @State private var failed = false

    private var episodeId: Int? { story.events.first { $0.episodeId != nil }?.episodeId }
    private var versionId: Int? { story.events.first { $0.editionId != nil }?.editionId }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        ActPoster(url: story.posterUrl, title: story.title, size: .md)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(story.title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                            Text([story.episodeLabel, story.tier.map { $0.chipLabel }].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(Theme.mut)
                        }
                    }
                    .padding(.bottom, 6)
                    if failed {
                        Text("The lifecycle could not be loaded. Check the backend and try again.").foregroundStyle(Theme.mut)
                    } else if let events {
                        if events.isEmpty { Text("No history yet").foregroundStyle(Theme.mut) }
                        ForEach(events) { HistoryRow(entry: $0) }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Lifecycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private func load() async {
        guard let client = model.client, let itemId = story.mediaItemId else { return }
        do {
            let page = try await client.historyLifecycle(itemId: itemId, episodeId: episodeId, versionId: versionId)
            events = page.items.sorted { $0.createdAt < $1.createdAt }
        } catch {
            failed = true
        }
    }
}
