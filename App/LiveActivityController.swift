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
    private(set) static var lastPaused = false
    /// The download that led the activity last, for the "Imported" moment.
    private static var lastLead: QueueItem?

    /// `paused` nil keeps the last known pause state.
    static func sync(with queue: [QueueItem], paused: Bool? = nil) {
        lastQueue = queue
        if let paused { lastPaused = paused }
        let paused = lastPaused
        // Account › Live Activity › Show on Lock Screen.
        guard LiveActivityPrefs.enabled else {
            if lastSettled != nil { endAll() }
            return
        }
        // Only the downloads chosen in Account › Live Activity count.
        let counted = queue.filter(LiveActivityPrefs.includes)
        guard let built = LiveActivityStateBuilder.build(counted) else {
            if lastSettled != nil {
                let final = LiveActivityStateBuilder.finished(lastLead)
                let minutes = LiveActivityPrefs.lingerMinutes
                Task { await worker.end(with: final, keepMinutes: minutes) }
            }
            lastSettled = nil
            lastLead = nil
            return
        }
        lastLead = counted.first { $0.id == built.rows.first?.downloadId } ?? lastLead ?? counted.first
        LiveActivityPosters.ensure(built)
        // Tiny posters ride in the state itself (see `ContentState.thumbs`).
        var withPause = built
        withPause.paused = paused ? true : nil
        let state = LiveActivityPosters.attach(withPause)
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
            // With a push token, fusionha can keep it current while the app is
            // closed (0.4.205); a build without push falls back to local only.
            if (try? Activity.request(attributes: DownloadsActivityAttributes(), content: content, pushType: .token)) == nil {
                _ = try? Activity.request(attributes: DownloadsActivityAttributes(), content: content, pushType: nil)
            }
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

    /// Tiny posters for the state itself, by media item id and size.
    private static var tiny: [String: Data] = [:]
    /// ActivityKit refuses a state over 4 KB; stay well under it.
    private static let stateBudget = 3_700

    /// Poster sizes to try, sharpest first: when every title's poster does
    /// not fit the budget at one size, the next, smaller one is tried.
    private static let sizes: [(w: CGFloat, h: CGFloat, q: CGFloat)] = [(40, 60, 0.45), (32, 48, 0.35), (24, 36, 0.3)]

    /// The state with tiny posters for every title that fits the budget: the
    /// event's title first, then the held titles, then the downloading rows.
    static func attach(_ state: DownloadsActivityAttributes.ContentState) -> DownloadsActivityAttributes.ContentState {
        var out = state
        out.thumbs = nil
        var candidates: [Int] = []
        if let event = state.event { candidates.append(event.mediaItemId) }
        candidates.append(contentsOf: state.held.map(\.mediaItemId))
        candidates.append(contentsOf: state.rows.map(\.mediaItemId))
        var ids: [Int] = []
        for id in candidates where !ids.contains(id) { ids.append(id) }
        ids = Array(ids.prefix(3))
        let encoder = JSONEncoder()
        var best: [String: Data] = [:]
        for size in sizes {
            var thumbs: [String: Data] = [:]
            for id in ids {
                guard let thumb = tinyThumb(id, size) else { continue }
                var trial = out
                trial.thumbs = thumbs.merging(["\(id)": thumb]) { _, new in new }
                if let bytes = try? encoder.encode(trial).count, bytes <= stateBudget { thumbs = trial.thumbs ?? thumbs }
            }
            if thumbs.count > best.count { best = thumbs }
            if best.count == ids.filter({ DownloadsActivityAttributes.ContentState.posterData(mediaItemId: $0) != nil }).count { break }
        }
        out.thumbs = best.isEmpty ? nil : best
        return out
    }

    private static func tinyThumb(_ id: Int, _ size: (w: CGFloat, h: CGFloat, q: CGFloat)) -> Data? {
        let key = "\(id)-\(Int(size.w))"
        if let hit = tiny[key] { return hit }
        guard let data = DownloadsActivityAttributes.ContentState.posterData(mediaItemId: id),
              let image = UIImage(data: data) else { return nil }
        let box = CGSize(width: size.w, height: size.h)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: box, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: box)) }
        guard let jpeg = small.jpegData(compressionQuality: size.q) else { return nil }
        tiny[key] = jpeg
        return jpeg
    }

    /// The size a poster went into the state at, for the poster check.
    private static func inState(_ id: Int) -> String? {
        let hits = sizes.compactMap { size in tiny["\(id)-\(Int(size.w))"].map { "\(Int(size.w))px \($0.count) B" } }
        return hits.isEmpty ? nil : hits.joined(separator: " / ")
    }

    /// What Account › Live Activity shows: saved count, the last problem, and
    /// for each poster where the app and the Lock Screen found it.
    static func diagnostics(ids: [Int]) -> [String] {
        var out = ["Saved this session: \(saved)" + (lastProblem.map { " · \($0)" } ?? "")]
        let seen = DownloadsActivityAttributes.ContentState.posterSeen()
        for id in ids.prefix(4) {
            out.append("#\(id) app: \(DownloadsActivityAttributes.ContentState.posterReport(mediaItemId: id))"
                       + (inState(id).map { " · thumbs \($0)" } ?? ""))
            out.append("#\(id) Lock Screen: \(seen["\(id)"] ?? "no report (it can't write to shared storage on this build)")")
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
