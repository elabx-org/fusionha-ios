import ActivityKit
import Foundation
import UIKit
import FusionhaKit

/// Starts, updates and ends the single "Downloads" Live Activity from app-side
/// polling (the redesigned states come from `LiveActivityStateBuilder`).
/// Updating it while the app is closed needs fusionha's Live Activity pushes
/// (asked in the handover doc, 2026-10-15); until then it goes stale and says
/// when it last updated.
///
/// The queue is polled every 2 s on the main actor. ActivityKit's
/// `areActivitiesEnabled` and `Activity.activities` are synchronous IPC, so
/// they run on `LiveActivityWorker` (off the main thread), and only when the
/// state actually changed.
@MainActor
enum LiveActivityController {
    private static var lastSettled: DownloadsActivityAttributes.ContentState?
    private static var lastSent = Date.distantPast
    private static let worker = LiveActivityWorker()
    /// The last queue seen, so a change in Account › Live Activity applies at once.
    private static var lastQueue: [QueueItem] = []
    /// The download that led the activity last, for the "Imported" moment.
    private static var lastLead: QueueItem?

    static func sync(with queue: [QueueItem]) {
        lastQueue = queue
        // Account › Live Activity › Show on Lock Screen.
        guard LiveActivityPrefs.enabled else {
            if lastSettled != nil { endAll() }
            return
        }
        // Only the downloads chosen in Account › Live Activity count.
        let counted = queue.filter(LiveActivityPrefs.includes)
        guard let state = LiveActivityStateBuilder.build(counted) else {
            if lastSettled != nil {
                let final = LiveActivityStateBuilder.finished(lastLead)
                let minutes = LiveActivityPrefs.lingerMinutes
                Task { await worker.end(with: final, keepMinutes: minutes) }
            }
            lastSettled = nil
            lastLead = nil
            return
        }
        lastLead = counted.first { $0.id == state.rows.first?.downloadId } ?? lastLead ?? counted.first
        LiveActivityPosters.ensure(state)
        // Send when something a person would notice changed, and at least
        // every 30 s so the time left and speed stay honest.
        let settled = state.settled
        guard settled != lastSettled || Date().timeIntervalSince(lastSent) >= 30 else { return }
        lastSettled = settled
        lastSent = Date()
        Task { await worker.apply(state) }
    }

    /// Applies a changed choice to the queue already on screen.
    static func resync() {
        lastSettled = nil
        sync(with: lastQueue)
    }

    static func endAll() {
        lastSettled = nil
        lastLead = nil
        Task { await worker.endAll() }
    }
}

/// Runs the ActivityKit calls in order, off the main thread.
actor LiveActivityWorker {
    private var current: Activity<DownloadsActivityAttributes>? {
        Activity<DownloadsActivityAttributes>.activities.first
    }

    func apply(_ state: DownloadsActivityAttributes.ContentState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Stale after 5 minutes without an update: the activity then says
        // when it last heard, instead of a frozen percent.
        let content = ActivityContent(state: state, staleDate: .now + 300)
        if let current {
            await current.update(content)
        } else {
            _ = try? Activity.request(attributes: DownloadsActivityAttributes(), content: content, pushType: nil)
        }
    }

    func end(with state: DownloadsActivityAttributes.ContentState, keepMinutes: Int) async {
        guard let current else { return }
        let policy: ActivityUIDismissalPolicy = keepMinutes > 0 ? .after(.now + Double(keepMinutes) * 60) : .immediate
        await current.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy)
    }

    func endAll() async {
        for activity in Activity<DownloadsActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// Small posters for the activity, written to the App Group (a Live
/// Activity cannot load images from the network itself).
@MainActor
enum LiveActivityPosters {
    private static var inFlight: Set<Int> = []

    static func ensure(_ state: DownloadsActivityAttributes.ContentState) {
        let wanted = state.rows.map { ($0.mediaItemId, $0.posterUrl) } + state.held.map { ($0.mediaItemId, $0.posterUrl) }
        for (id, posterUrl) in wanted {
            guard let url = posterUrl, !inFlight.contains(id),
                  let file = DownloadsActivityAttributes.ContentState.posterFile(mediaItemId: id),
                  !FileManager.default.fileExists(atPath: file.path) else { continue }
            inFlight.insert(id)
            Task.detached(priority: .utility) {
                defer { Task { @MainActor in inFlight.remove(id) } }
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = UIImage(data: data) else { return }
                // About 2x the 40pt poster: small enough for ActivityKit's limits.
                let size = CGSize(width: 80, height: 120)
                let small = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                guard let jpeg = small.jpegData(compressionQuality: 0.7) else { return }
                try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? jpeg.write(to: file, options: .atomic)
            }
        }
    }
}
