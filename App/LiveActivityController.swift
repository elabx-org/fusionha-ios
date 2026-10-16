import ActivityKit
import Foundation
import Security
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

    /// The titles on the queue the activity last saw, for poster diagnostics.
    static var itemIds: [Int] {
        var seen = Set<Int>()
        return lastQueue.map(\.mediaItemId).filter { seen.insert($0).inserted }
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

/// Small posters for the activity (a Live Activity cannot load images from
/// the network itself), written to the App Group and to the shared keychain:
/// a build re-signed without the App Group has no shared container, so the
/// keychain copy is the one the widget extension finds. Once a poster lands
/// the activity is re-sent so it shows straight away.
@MainActor
enum LiveActivityPosters {
    private static var inFlight: Set<Int> = []
    /// Keychain copies kept, newest last; older ones are deleted.
    private static let indexAccount = "la-poster-index"
    private static let keep = 12
    /// The last fetch or save problem, for Account › Live Activity.
    private(set) static var lastProblem: String?
    private(set) static var saved = 0

    static func ensure(_ state: DownloadsActivityAttributes.ContentState) {
        let wanted = state.rows.map { ($0.mediaItemId, $0.posterUrl) } + state.held.map { ($0.mediaItemId, $0.posterUrl) }
        for (id, posterUrl) in wanted {
            guard let url = posterUrl, !inFlight.contains(id),
                  DownloadsActivityAttributes.ContentState.posterData(mediaItemId: id) == nil else { continue }
            inFlight.insert(id)
            Task.detached(priority: .utility) {
                let result = await Self.thumbnail(url)
                await MainActor.run {
                    inFlight.remove(id)
                    switch result {
                    case .success(let jpeg):
                        store(jpeg, mediaItemId: id)
                        LiveActivityController.resync()
                    case .failure(let error):
                        lastProblem = "Poster \(id): \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    struct ThumbnailError: LocalizedError {
        let errorDescription: String?
    }

    /// 120×180 px (2x the 60pt tile, fixed so the device scale can't triple
    /// it) at 0.6 quality: a few KB, small enough for a keychain item.
    nonisolated private static func thumbnail(_ url: URL) async -> Result<Data, Error> {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                return .failure(ThumbnailError(errorDescription: "HTTP \(http.statusCode) from \(url.host ?? "?")"))
            }
            guard let image = UIImage(data: data) else { return .failure(ThumbnailError(errorDescription: "not an image")) }
            let size = CGSize(width: 60, height: 90)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            guard let jpeg = small.jpegData(compressionQuality: 0.6) else { return .failure(ThumbnailError(errorDescription: "JPEG failed")) }
            return .success(jpeg)
        } catch {
            return .failure(error)
        }
    }

    /// What Account › Live Activity shows: saved count, the last problem, and
    /// for each poster where the app and the Lock Screen found it.
    static func diagnostics(ids: [Int]) -> [String] {
        var out = ["Saved this session: \(saved)" + (lastProblem.map { " · \($0)" } ?? "")]
        let seen = DownloadsActivityAttributes.ContentState.posterSeen()
        for id in ids.prefix(4) {
            out.append("#\(id) app: \(DownloadsActivityAttributes.ContentState.posterReport(mediaItemId: id))")
            out.append("#\(id) Lock Screen: \(seen["\(id)"] ?? "not drawn yet")")
        }
        return out
    }

    private static func store(_ jpeg: Data, mediaItemId id: Int) {
        if let file = DownloadsActivityAttributes.ContentState.posterFile(mediaItemId: id) {
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? jpeg.write(to: file, options: .atomic)
        }
        let status = SharedKeychain.write(jpeg, DownloadsActivityAttributes.ContentState.posterAccount(mediaItemId: id))
        if status == errSecSuccess { saved += 1 } else { lastProblem = "Poster \(id): keychain \(status)" }
        var index = (SharedKeychain.read(indexAccount).flatMap { try? JSONDecoder().decode([Int].self, from: $0) }) ?? []
        index.removeAll { $0 == id }
        index.append(id)
        while index.count > keep {
            SharedKeychain.delete(DownloadsActivityAttributes.ContentState.posterAccount(mediaItemId: index.removeFirst()))
        }
        if let data = try? JSONEncoder().encode(index) { SharedKeychain.write(data, indexAccount) }
    }
}
