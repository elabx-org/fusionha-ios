import SwiftUI
import FusionhaKit

// MARK: - Discover card

/// `DiscoverCard`: a clean 2:3 poster with a corner status badge, then title
/// and a `year · kind` line with the provider mark and request chip.
struct DiscoverCard: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    let result: MediaSearchResult
    var trending = false
    let canAdd: Bool
    let canRequest: Bool
    @State private var checking = false

    /// Discover rows carry only `in_library`; the id comes from the library list
    /// (the web's `idByTmdb`), or the row itself on search results.
    private var inLibrary: Bool { result.inLibrary || result.libraryItemId != nil }
    private var libraryId: Int? { inLibrary ? model.libraryItemId(for: result) : nil }
    private var requestStatus: String? { store.statusByTmdb[result.tmdbId] }
    private var alreadyRequested: Bool { requestStatus == "pending" || requestStatus == "approved" }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                poster
                meta
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DiscoverPressStyle())
        #if DEBUG
        .task(id: model.libraryLoaded) { screenshotOpen() }
        #endif
        .contextMenu { menu } preview: {
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w780"))
                .frame(width: 220, height: 330)
        }
    }

    private var poster: some View {
        Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { DiscoverArt(url: TMDBImage.resized(result.posterUrl, to: "w500")) }
            .shelfPoster()
    }

    /// In library / trending: a mark on the meta line, never on the art.
    @ViewBuilder
    private var statusMark: some View {
        if inLibrary {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.done)
                .accessibilityLabel("In library")
        } else if trending {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.onair)
                .accessibilityLabel("Trending")
        }
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The Library card's text size, so a poster reads the same on both.
            Text(result.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    if let year = result.displayYear { Text(verbatim: "\(year) · ") }
                    DiscoverKindGlyph(kind: result.kind, isAnime: result.isAnime)
                }
                .lineLimit(1)
                .fixedSize()
                .font(.system(size: 13))
                .foregroundStyle(Theme.dim)
                Spacer(minLength: 0)
                providerException
                statusMark
                if !inLibrary, let status = requestStatus, status == "pending" || status == "approved" {
                    let color = status == "pending" ? Theme.miss : Theme.done
                    Text(status == "pending" ? "Requested" : "Approved")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.16), in: Capsule())
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 1)
    }

    @ViewBuilder
    private var providerException: some View {
        let global = DiscoverSession.shared.globalProvider
        if result.kind == .movie && global != "tmdb" {
            TmdbLogo(size: 9, label: "TMDB")
        } else if result.kind == .series && global == "tvdb" {
            TvdbLogo(size: 11, label: "TVDB")
        }
    }

    #if DEBUG
    /// `FUSIONHA_SCREENSHOT_DISCOVER_OPEN=<tmdb id>` taps that card once, through
    /// the same `open()` a finger would.
    private static var screenshotOpened = false
    private func screenshotOpen() {
        guard !Self.screenshotOpened, model.libraryLoaded,
              ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_DISCOVER_OPEN"] == String(result.tmdbId) else { return }
        Self.screenshotOpened = true
        open()
    }
    #endif

    private func open() {
        if inLibrary {
            if let id = libraryId, !model.requestScoped {
                model.open(id)
            } else {
                // Not in the loaded list yet: the preview resolves the item and
                // offers "Open in library".
                store.preview = PreviewRoute(result)
            }
        } else if canAdd {
            store.preview = PreviewRoute(result)
        } else if canRequest && !alreadyRequested {
            store.requestPick = result
        }
    }

    @ViewBuilder
    private var menu: some View {
        if inLibrary {
            if let id = libraryId {
                if !model.requestScoped {
                    Button { model.open(id) } label: { Label("Open", systemImage: "arrow.up.right.square") }
                }
                Button { Task { await checkLibrary(id) } } label: {
                    Label(checking ? "Checking…" : "Check for 4K", systemImage: "4k.tv")
                }
                .disabled(checking)
            } else {
                Button { store.preview = PreviewRoute(result) } label: { Label("View details", systemImage: "eye") }
            }
        } else {
            // Add-capable: a tap already opens details, listed first; then the
            // Add sheet straight on this title, then the pre-add 4K probe (0.4.133).
            if canAdd {
                Button { store.preview = PreviewRoute(result) } label: { Label("View details", systemImage: "eye") }
                Button {
                    model.openAdd(result, providerOverride: DiscoverSession.shared.providerOverride)
                } label: { Label("Add to library", systemImage: "plus") }
            } else if canRequest && !alreadyRequested {
                Button { store.requestPick = result } label: { Label("Request", systemImage: "paperplane") }
            }
            Button { Task { await checkDiscover() } } label: {
                Label(checking ? "Checking…" : "Check for 4K", systemImage: "4k.tv")
            }
            .disabled(checking)
            if !canAdd {
                Button { store.preview = PreviewRoute(result) } label: { Label("View details", systemImage: "eye") }
            }
        }
    }

    private func checkLibrary(_ id: Int) async {
        guard let client = model.client else { return }
        checking = true
        defer { checking = false }
        do {
            let r = try await client.libraryCheckFourK(itemId: id)
            var message = (r.message?.isEmpty == false ? r.message! : "Checked \(result.title) for 4K.")
            if r.foundUhd { message += " See Wanted → 4K Available for details." }
            DiscoverToasts.shared.show(r.foundUhd ? .success : .info, message)
        } catch {
            DiscoverToasts.shared.error("Could not check for 4K", error)
        }
    }

    private func checkDiscover() async {
        guard let client = model.client else { return }
        checking = true
        defer { checking = false }
        do {
            let r = try await client.discoverCheckFourK(DiscoverCheckFourKBody(
                tmdbId: result.tmdbId, title: result.title, kind: result.kind,
                year: result.displayYear, isAnime: result.isAnime))
            if r.foundUhd {
                let n = r.queriedIndexers ?? 0
                DiscoverToasts.shared.show(.success, "\(result.title): genuine 4K available (seen on \(n) indexer\(n == 1 ? "" : "s")). Enable 4K when you add it to grab it.")
            } else {
                DiscoverToasts.shared.show(.info, "\(result.title): no genuine 4K found right now.")
            }
        } catch {
            DiscoverToasts.shared.error("Could not check for 4K", error)
        }
    }
}
