import SwiftUI
import FusionhaKit

/// Someone's public Letterboxd watchlist by username (the 10a flow, which has
/// no address; web `AddSourcePanel` opened on watchlist): preview the first
/// page, then Follow what was previewed.
@MainActor
@Observable
final class WatchlistFollowModel {
    var username = ""
    var error: String?
    var preview: LbSourcePreview?
    var previewed: LbSourceTarget?
    var nextPreviewAt: Date?
    var reading = false
    var adding = false
    var existing = false

    var target: LbSourceTarget { .watchlist(username: username.trimmingCharacters(in: .whitespaces)) }
    var ready: Bool { LetterboxdLogic.validUsername(username) }
    var shown: LbSourcePreview? { previewed == nil ? nil : preview }

    func typedChanged() {
        preview = nil
        previewed = nil
        error = nil
    }

    func canPreview(now: Date = Date()) -> Bool {
        ready && !reading && (nextPreviewAt.map { $0 <= now } ?? true)
    }

    func submit(_ store: WatchlistsStore, _ model: AppModel, done: @escaping () -> Void) {
        if previewed == target, preview != nil { add(store, model, done: done) } else if canPreview() { runPreview(model.client) }
    }

    func runPreview(_ client: APIClient?) {
        guard let client, ready else { return }
        let sent = target
        error = nil
        reading = true
        Task {
            defer { reading = false }
            do {
                let result = try await client.previewRequestSource(sent)
                guard sent == target else { return }
                preview = result
                previewed = sent
                nextPreviewAt = Date().addingTimeInterval(30)
            } catch {
                guard sent == target else { return }
                if let at = (error as? APIError)?.retryAt { nextPreviewAt = ServerTime.parse(at) }
                preview = nil
                self.error = FeedFollowLogic.watchlistMessage(for: error)
            }
        }
    }

    private func add(_ store: WatchlistsStore, _ model: AppModel, done: @escaping () -> Void) {
        guard let client = model.client, let previewed, !adding else { return }
        let existing = existing
        adding = true
        Task {
            defer { adding = false }
            do {
                _ = try await client.addRequestSource(previewed, enabled: true, requestExisting: existing)
                model.toast(FollowCopy.following("@\(preview?.owner ?? "")’s watchlist"))
                await store.load(client)
                done()
            } catch {
                self.error = WatchlistErrorCopy.letterboxdMessage(for: error, watchlist: true)
            }
        }
    }
}
