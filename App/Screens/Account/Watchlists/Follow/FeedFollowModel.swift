import SwiftUI
import FusionhaKit

/// "Follow a list" by address (web `FeedFollowPanel`, fusionha 0.4.237): any
/// public MDBList, Trakt or Letterboxd list. Preview (30 s apart) reads the
/// site, the facts, the mix and a poster strip; Follow adds exactly the
/// address that was previewed.
@MainActor
@Observable
final class FeedFollowModel {
    var url = ""
    var message: FeedMessage?
    var preview: LbSourcePreview?
    /// The address the shown preview is for.
    var previewed: String?
    var nextPreviewAt: Date?
    var reading = false
    var adding = false
    var existing = false
    var uhd = false

    struct FeedMessage: Equatable {
        let text: String
        var tip: String?
    }

    var typed: String { url.trimmingCharacters(in: .whitespaces) }
    var isPlex: Bool { FeedFollowLogic.isPlexAddress(typed) }
    var ready: Bool { FeedFollowLogic.ready(typed) }
    var shown: LbSourcePreview? { previewed == nil ? nil : preview }
    /// A Letterboxd list follows the diary's UHD·4K; a feed has its own.
    var isLetterboxd: Bool { preview?.site == .letterboxd }

    /// A new address drops the old preview and its message.
    func typedChanged() {
        preview = nil
        previewed = nil
        message = nil
    }

    func canPreview(now: Date = Date()) -> Bool {
        ready && !reading && (nextPreviewAt.map { $0 <= now } ?? true)
    }

    /// The toolbar's confirm: follow what was previewed, else preview first.
    func submit(_ store: WatchlistsStore, _ model: AppModel, uhdAllowed: Bool, done: @escaping () -> Void) {
        if previewed != nil, previewed == typed, preview != nil {
            follow(store, model, uhdAllowed: uhdAllowed, done: done)
        } else if canPreview() {
            runPreview(model.client)
        }
    }

    func runPreview(_ client: APIClient?) {
        guard let client, ready else { return }
        let sent = typed
        message = nil
        reading = true
        Task {
            defer { reading = false }
            do {
                let result = try await client.previewListAddress(sent)
                // A late answer for an older address is dropped.
                guard sent == typed else { return }
                preview = result
                previewed = sent
                nextPreviewAt = Date().addingTimeInterval(30)
            } catch {
                guard sent == typed else { return }
                if let at = (error as? APIError)?.retryAt { nextPreviewAt = ServerTime.parse(at) }
                preview = nil
                let m = FeedFollowLogic.message(for: error, guess: FeedFollowLogic.guessProvider(sent))
                message = FeedMessage(text: m.text, tip: m.tip)
            }
        }
    }

    private func follow(_ store: WatchlistsStore, _ model: AppModel, uhdAllowed: Bool, done: @escaping () -> Void) {
        guard let client = model.client, let previewed, !adding else { return }
        let letterboxd = isLetterboxd
        let request = (existing: existing, uhd: uhd && uhdAllowed)
        adding = true
        Task {
            defer { adding = false }
            do {
                _ = try await client.followListAddress(previewed, letterboxd: letterboxd,
                                                       requestExisting: request.existing, alsoUhd: request.uhd)
                model.toast(FollowCopy.following(preview?.title ?? preview?.owner.map { "@\($0)" } ?? "the list"))
                await store.load(client)
                done()
            } catch {
                let m = FeedFollowLogic.message(for: error, guess: FeedFollowLogic.guessProvider(previewed))
                message = FeedMessage(text: m.text, tip: m.tip)
            }
        }
    }
}
