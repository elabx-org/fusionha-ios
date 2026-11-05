import SwiftUI
import FusionhaKit

/// The downloads bar's press-and-hold menu (mock `accMenu`): Open the queue,
/// one Review entry per held download (each opens its decision), Manual
/// Import for all of them, then Process the queue now and Pause downloads
/// (the web's operations panel lives here on iOS).
struct V2DownloadsMenu: View {
    let summary: DownloadsBar.Summary
    @Binding var confirmPause: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Open the queue · \(model.queueTotal)", systemImage: "waveform.path.ecg") {
            V2DownloadsLinks.openQueue(model, focus: nil)
        }
        ForEach(V2DownloadsLinks.held(model.queue).prefix(8)) { item in
            Button(V2DownloadsLinks.reviewLabel(item), systemImage: "pause.circle") {
                V2DownloadsLinks.openQueue(model, focus: item.id)
            }
        }
        if summary.heldIds.count > 1 {
            Button("Review all \(summary.heldIds.count) in Manual Import", systemImage: "square.and.arrow.down") {
                model.pendingRescueIds = summary.heldIds
                model.tab = .activity
            }
        }
        Divider()
        Button("Process the queue now", systemImage: "arrow.clockwise") {
            Task {
                _ = try? await model.client?.processQueueNow()
                await model.refreshQueue()
            }
        }
        if model.me?.isAdmin == true {
            let paused = model.queuePaused
            Button(paused ? "Resume downloads" : "Pause downloads", systemImage: paused ? "play.fill" : "pause.fill") {
                if paused { Task { await model.toggleQueuePause() } } else { confirmPause = true }
            }
        }
        Button("Open title", systemImage: "film") { model.presentedItem = ItemRef(id: summary.mediaItemId) }
    }
}

/// The bar's links into the queue and its words.
@MainActor
enum V2DownloadsLinks {
    /// Activity › Queue; with a download, scrolled to it (a held one opens
    /// its decision in v2's queue).
    static func openQueue(_ model: AppModel, focus downloadId: Int?) {
        let link = downloadId.map { "activity/queue?focus=\($0)" } ?? "activity/queue"
        if let url = AppIdentity.current.link(link) { model.handleDeepLink(url) }
    }

    static func held(_ queue: [QueueItem]) -> [QueueItem] {
        queue.filter { $0.status.lowercased() == "held" }
    }

    /// "Review VisionQuest S01E07 4K".
    static func reviewLabel(_ item: QueueItem) -> String {
        (["Review", item.title, item.episodeLabel, item.tier.badgeLetters].compactMap { $0 }).joined(separator: " ")
    }

    /// "4 min left · 2 need you", "3 downloading · 2 need you", or v1's line.
    static func line(_ s: DownloadsBar.Summary) -> String {
        var parts: [String] = []
        if s.downloading > 0 {
            parts.append(s.etaSeconds.map { "\(DownloadsBar.duration($0)) left" } ?? "\(s.downloading) downloading")
        }
        if s.needCount > 0 { parts.append("\(s.needCount) need\(s.needCount == 1 ? "s" : "") you") }
        return parts.isEmpty ? DownloadsBar.detailLine(s) : parts.joined(separator: " · ")
    }
}
