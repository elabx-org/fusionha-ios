import SwiftUI
import FusionhaKit

/// An "Available to add" row: ★ rating (or the release date when it has none),
/// then + Add (with `add`) and person Request (with `request`), each gated on
/// its own capability (web `rowActions`). The row opens the preview (add), or
/// the request modal. A title only TheTVDB has carries the one row mark
/// (option A: the TVDB mark + "only") and opens the Add sheet on its TVDB id.
struct SearchAddRow: View {
    @Environment(AppModel.self) private var model
    let hit: UnifiedAddHit
    let actions: SearchAddActions

    private var canAdd: Bool { model.me.map { $0.hasCapability("add") } ?? !model.requestScoped }
    private var canRequest: Bool { model.me?.hasCapability("request") == true }

    var body: some View {
        Button(action: primary) {
            SearchRow(posterUrl: hit.posterUrl, dot: dot, title: hit.title,
                      meta: SearchRowText.meta(year: hit.year, kind: kindName), picked: picked) {
                if hit.isTvdbOnly {
                    HStack(spacing: 4) {
                        TvdbLogo(size: 10, label: "TheTVDB")
                        Text("only").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
                    }
                }
            } accessory: {
                rating
            } actions: {
                HStack(spacing: 0) {
                    ForEach(rowActions, id: \.self) { action in
                        switch action {
                        case .add: SearchRowButton(kind: .add, action: add)
                        case .request: SearchRowButton(kind: .request, action: request)
                        case .open: SearchRowButton(kind: .open, action: primary)
                        }
                    }
                }
            }
        }
        .buttonStyle(SearchRowStyle())
    }

    @ViewBuilder
    private var rating: some View {
        if let vote = hit.tmdb?.voteAverage, vote > 0 {
            Text("★ \(String(format: "%.1f", vote))")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .monospacedDigit()
        } else if let soon = upcoming {
            Text(soon).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.miss)
        }
    }

    /// "Dec 2026" for a title not out yet.
    private var upcoming: String? {
        guard let raw = hit.tmdb?.date, raw.count >= 10 else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: String(raw.prefix(10))), date > .now else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    private var dot: Color {
        if hit.tmdb?.isAnime == true { return Theme.kindAnime }
        return hit.kind == .movie ? Theme.kindMovie : Theme.kindSeries
    }

    private var kindName: String {
        if hit.tmdb?.isAnime == true { return "Anime" }
        return hit.kind == .movie ? "Movie" : "Series"
    }

    private var picked: Bool {
        guard let result = hit.tmdb else { return false }
        return result.isPicked(in: model, libraryId: nil)
    }

    /// A TheTVDB-only title can be added but not requested (requests need a TMDB id).
    private var rowActions: [OmniActions.Action] {
        OmniActions.addRowActions(openable: openable != nil, canAdd: canAdd,
                                  canRequest: canRequest && hit.tmdb != nil)
    }

    /// A requester's row for a title the server already has.
    private var openable: Int? {
        guard let result = hit.tmdb, result.inLibrary, !model.requestScoped else { return nil }
        return model.libraryItemId(for: result)
    }

    private func primary() {
        switch OmniActions.addRowPrimary(openable: openable != nil, canAdd: canAdd,
                                         canRequest: canRequest && hit.tmdb != nil) {
        case .open: if let id = openable { model.open(id) }
        case .preview:
            if let result = hit.tmdb { actions.preview(result) } else if let tvdb = hit.tvdb { actions.addTvdb(tvdb) }
        case .request: request()
        case .none: break
        }
    }

    private func add() {
        if let result = hit.tmdb { model.openAdd(result) } else if let tvdb = hit.tvdb { actions.addTvdb(tvdb) }
    }

    private func request() {
        if let result = hit.tmdb { actions.request(result) }
    }
}

/// What an add row hands back to the Search tab (its sheets live there).
struct SearchAddActions {
    var preview: (MediaSearchResult) -> Void
    var request: (MediaSearchResult) -> Void
    var addTvdb: (TvdbSearchResult) -> Void
}
