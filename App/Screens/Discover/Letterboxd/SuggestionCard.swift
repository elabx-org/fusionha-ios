import SwiftUI
import FusionhaKit

/// One "From your Letterboxd" card (web `SuggestionCard`): a clean poster,
/// "Title (year)", the source line (and the stale note), then the actions:
/// Request with its tier caret, Me too when someone already asked, Add to
/// wishlist over the weekly limit, and Requested / On your wishlist once done.
struct SuggestionCard: View {
    static let width: CGFloat = 134

    let item: Suggestion
    let overLimit: Bool
    let uhdAllowed: Bool
    /// False for a viewer who can't request: the card shows no actions.
    let actionable: Bool
    /// A request or join went through (the rail re-reads the quota).
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @State private var done: SuggestionRail.Done?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay { DiscoverArt(url: TMDBImage.resized(item.poster, to: "w500")) }
                .shelfPoster()
                .accessibilityHidden(true)
            title
            source
            if actionable {
                SuggestionCardActions(item: item,
                                      action: SuggestionRail.action(askedCount: item.askedCount, done: done,
                                                                    overLimit: overLimit),
                                      uhdAllowed: uhdAllowed, working: working,
                                      request: { tiers in Task { await request(tiers) } },
                                      meToo: { Task { await meToo() } },
                                      more: { store.requestPick = item.searchResult })
            }
        }
        .frame(width: Self.width, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title)
    }

    private var title: some View {
        (Text(item.title).fontWeight(.bold).foregroundColor(Theme.txt)
            + Text(verbatim: item.year.map { " (\($0))" } ?? "").fontWeight(.medium).foregroundColor(Theme.mut))
            .font(.system(size: 13))
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var source: some View {
        if item.sourceLabel != nil || item.stale {
            VStack(alignment: .leading, spacing: 1) {
                if let label = item.sourceLabel {
                    Text(label).foregroundStyle(Theme.dim).lineLimit(2)
                }
                if item.stale {
                    Text(SuggestionRail.staleNote).foregroundStyle(Theme.stuck)
                }
            }
            .font(.system(size: 11))
        }
    }

    private var kind: MediaKind { item.searchResult.kind }

    private func request(_ tiers: [QualityTier]) async {
        guard let client = model.client, !working else { return }
        let wishlist = overLimit
        working = true
        defer { working = false }
        do {
            _ = try await client.submitRequest(RequestCreateBody(tmdbId: item.tmdbId, kind: kind, editions: tiers,
                                                                 wishlist: wishlist))
            done = SuggestionRail.done(afterRequest: wishlist)
            DiscoverToasts.shared.show(.success, SuggestionRail.requestedToast(item.title, wishlist: wishlist))
            onDone()
        } catch {
            DiscoverToasts.shared.show(.error, ErrorCopy.message(for: error))
        }
    }

    private func meToo() async {
        guard let client = model.client, !working else { return }
        working = true
        defer { working = false }
        do {
            _ = try await client.submitRequest(RequestCreateBody(tmdbId: item.tmdbId, kind: kind, editions: [.hd],
                                                                 join: true))
            done = .requested
            DiscoverToasts.shared.show(.success, SuggestionRail.joinedToast(item.title))
            onDone()
        } catch {
            DiscoverToasts.shared.show(.error, ErrorCopy.message(for: error))
        }
    }
}
