import SwiftUI
import UIKit
import FusionhaKit

// MARK: - Search tab

/// The iOS 26 search tab, holding the web's omni search (OmniSearchOverlay +
/// OmniResults): owned titles first ("In your library", capped at 8), then a
/// TMDB add lane that arms itself when nothing owned matches. The field is the
/// system's `.searchable` one (it shows now that the tab has its own stack,
/// DC11), focused when the tab opens. On the open iPhone Duo (S3): in a
/// Spread both lanes are poster grids spanning both pages until a result is
/// tapped (it opens on the right page, the grid moves to the left page); in
/// the Web layout the list stays before the fold.
struct SearchTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread
    /// For the Spread's Discover cards: their preview and request sheets.
    @State private var store = DiscoverStore()
    @State private var armed = false
    @State private var remote: [MediaSearchResult] = []
    @State private var searching = false
    @State private var failed = false
    /// The server has no TMDB key (409 `tmdb_not_configured`).
    @State private var noKey = false
    @State private var searchedTerm = ""
    @FocusState private var focused: Bool

    private var term: String { model.searchQuery }
    private var trimmed: String { term.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        @Bindable var model = model
        @Bindable var store = store
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if trimmed.isEmpty { hint } else { results }
            }
            .padding(.top, 8)
            .padding(.bottom, 40)
            // The Web layout on the open Duo: the list before the fold (the
            // web's omni search is a centred palette, there on the fold).
            .foldLeadingColumn(!spread.isActive)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg.ignoresSafeArea())
        .shellPage("Search")
        // The search tab's system field (DC11), now that the tab has a stack.
        .searchable(text: $model.searchQuery,
                    prompt: model.requestScoped ? "Find something to request…" : "Search your library or add something new…")
        .searchFocused($focused)
        // Typing survives a fold, unfold or rotation (D5).
        .keepsFocusAcrossResize($focused)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onSubmit(of: .search) { armed = true }
        .spreadSpansBothPages(.search, !trimmed.isEmpty)
        .environment(store)
        // A requester's pick: the request modal (web OmniResults → RequestModal).
        .duoPageSheet(item: $store.requestPick, placement: .twoPages) { pick in
            NavigationStack { RequestModal(pick: pick) {} }
        }
        .spreadPreviewHost(.search, preview: $store.preview, onOpenLibrary: { model.open($0) })
        .task {
            // Open ready to type, as a search tab does.
            try? await Task.sleep(for: .milliseconds(350))
            focused = true
        }
        .onChange(of: model.searchFocusTick) { focused = true }
        .task {
            if !model.libraryLoaded && !model.requestScoped { await model.loadLibrary() }
        }
        .onChange(of: term) { armed = false }
        .task(id: "\(trimmed)|\(shouldSearch)") {
            guard shouldSearch, !trimmed.isEmpty else { remote = []; searchedTerm = ""; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let client = model.client else { return }
            searching = true
            failed = false
            noKey = false
            do {
                remote = try await client.search(term: trimmed, kind: .all)
            } catch {
                if !Task.isCancelled {
                    if case APIError.http(status: 409, body: let body) = error, body.contains("tmdb_not_configured") {
                        noKey = true
                    } else {
                        failed = true
                    }
                    remote = []
                }
            }
            searchedTerm = trimmed
            searching = false
        }
    }

    private var hint: some View {
        Text(model.requestScoped
             ? "Search for a movie or series to request."
             : "Search your library, or find something new to add.")
            .font(.system(size: 15))
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, Theme.pageGutter)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
    }

    // MARK: Owned lane

    private var owned: (rows: [MediaItem], total: Int) {
        guard !model.requestScoped else { return ([], 0) }
        return Self.ownedMatches(model.library, term: trimmed)
    }

    /// useOmniOwned: substring match, a trailing 4-digit year filters, prefix
    /// matches first, then newest year first; capped at 8.
    static func ownedMatches(_ items: [MediaItem], term: String) -> (rows: [MediaItem], total: Int) {
        let q = term.lowercased()
        guard !q.isEmpty else { return ([], 0) }
        var title = q
        var year: Int?
        let pattern = try? NSRegularExpression(pattern: #"^(.*?)[\s(]*\b(\d{4})\)?\s*$"#)
        let ns = q as NSString
        if let m = pattern?.firstMatch(in: q, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges == 3 {
            let head = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if !head.isEmpty {
                title = head
                year = Int(ns.substring(with: m.range(at: 2)))
            }
        }
        var scored: [(MediaItem, Int)] = []
        for item in items {
            if let year, let y = item.year, y != year { continue }
            let t = item.title.lowercased()
            guard let range = t.range(of: title) else { continue }
            scored.append((item, range.lowerBound == t.startIndex ? 0 : 1))
        }
        scored.sort { a, b in a.1 != b.1 ? a.1 < b.1 : (a.0.year ?? 0) > (b.0.year ?? 0) }
        return (scored.prefix(8).map(\.0), scored.count)
    }

    private var shouldSearch: Bool {
        model.requestScoped || armed || owned.total == 0
    }

    @ViewBuilder
    private var results: some View {
        let owned = self.owned
        if !model.requestScoped {
            if owned.total > 0 {
                groupLabel("In your library", count: owned.total)
                if spread.isActive {
                    SearchOwnedGrid(items: owned.rows)
                } else {
                    ForEach(owned.rows) { ownedRow($0) }
                }
                if owned.total > owned.rows.count {
                    moreInLibrary(owned.total - owned.rows.count)
                }
            } else {
                nothingOwned
            }
        }

        if !shouldSearch {
            Button { armed = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.i2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search to add").font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                        Text("Not what you're looking for? Find something new to \(model.requestScoped ? "request" : "add")")
                            .font(.system(size: 12)).foregroundStyle(Theme.mut)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.i2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.i2.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .foldLeadingColumn()
        } else {
            addLane
        }
    }

    private func ownedRow(_ item: MediaItem) -> some View {
        Button {
            model.open(item.id)
        } label: {
            OmniRow(posterUrl: item.posterUrl, dot: Theme.kind(item.kindBucket), title: item.title,
                    year: item.year) {
                TierComboLabel(tiers: item.editions.map(\.tier))
            } action: {
                OmniIconButton(symbol: "arrow.up.right", label: "Open") { model.open(item.id) }
            }
        }
        .buttonStyle(OmniRowStyle())
    }

    private func moreInLibrary(_ count: Int) -> some View {
        Button {
            model.searchText = trimmed
            model.searchScope = .library
            model.tab = .library
        } label: {
            Text("+ \(count) more in Library")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.i2)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var nothingOwned: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.mut)
                .frame(width: 36, height: 36)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing in your library for “\(trimmed)”")
                    .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                Text("No owned titles matched — searching to add…")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var addLane: some View {
        if searching || searchedTerm != trimmed {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.mut)
                Text("Searching to add…").font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
            .padding(16)
        } else if noKey {
            note("Adding needs a TMDB key — add one in Settings › Metadata.")
        } else if failed {
            note("Couldn't reach the metadata provider — try again.")
        } else if remote.isEmpty {
            note("Nothing to add for “\(trimmed)”.")
        } else {
            groupLabel("Available to add",
                       credit: "· via \(OmniActions.providerShortLabel(model.settings?.metadataProvider))",
                       count: remote.count)
            if spread.isActive {
                SearchAddGrid(results: remote)
            } else {
                ForEach(remote) { result in
                    OmniAddRow(result: result, close: {}, request: { store.requestPick = $0 })
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(Theme.mut).padding(16)
    }

    private func groupLabel(_ text: String, credit: String? = nil, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(text.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.dim)
            if let credit {
                // The web keeps the provider credit in its own case.
                Text(credit).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            Text("\(count)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.dim)
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
