import SwiftUI
import UIKit
import FusionhaKit

// MARK: - Search tab

/// The iOS 26 search tab, holding the web's omni search (OmniSearchOverlay +
/// OmniResults): owned titles first ("In your library", capped at 8), then a
/// TMDB add lane that arms itself when nothing owned matches. The field is our
/// own glass field docked above the tab bar, focused when the tab opens (the
/// system's `.searchable` field never showed in this shell).
struct SearchTabView: View {
    @Environment(AppModel.self) private var model
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ShellTitleRow("Search")
                    .padding(.horizontal, Theme.pageGutter)
                    .padding(.top, 20)
                    .padding(.bottom, 4)
                if trimmed.isEmpty { hint } else { results }
            }
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture { if trimmed.isEmpty { focused = true } }
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .top) { StatusBarFade() }
        .safeAreaInset(edge: .bottom, spacing: 0) { field }
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

    private var field: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.mut)
            TextField("", text: $model.searchQuery,
                      prompt: Text(model.requestScoped ? "Find something to request" : "Your library or something new")
                        .foregroundStyle(Theme.mut))
                .font(.system(size: 16))
                .foregroundStyle(Theme.txt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .onSubmit { armed = true }
            if !model.searchQuery.isEmpty {
                Button {
                    model.searchQuery = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.mut)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 48)
        .contentShape(Capsule())
        .onTapGesture { focused = true }
        .glassControl(on: focused)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var hint: some View {
        Text(model.requestScoped
             ? "Search for a movie or series to request."
             : "Search your library, or find something new to add.")
            .font(.system(size: 15))
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, Theme.pageGutter)
            .padding(.top, 8)
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
                ForEach(owned.rows) { item in
                    Button {
                        model.open(item.id)
                    } label: {
                        OmniRow(posterUrl: item.posterUrl, dot: Theme.kind(item.kindBucket), title: item.title,
                                year: item.year) {
                            TierComboLabel(tiers: item.editions.map(\.tier))
                        } action: {
                            openLabel
                        }
                    }
                    .buttonStyle(OmniRowStyle())
                }
                if owned.total > owned.rows.count {
                    Button {
                        model.searchText = trimmed
                        model.searchScope = .library
                        model.tab = .library
                    } label: {
                        Text("+ \(owned.total - owned.rows.count) more in Library")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.i2)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            } else {
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
        } else {
            addLane
        }
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
            groupLabel("Available to add · via TMDB", count: remote.count)
            ForEach(remote) { result in
                OmniAddRow(result: result) {}
            }
        }
    }

    private var openLabel: some View {
        Text("Open ↗")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.mut)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(Theme.mut).padding(16)
    }

    private func groupLabel(_ text: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(text.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.dim)
            Text("\(count)").font(.system(size: 10.5, weight: .bold, design: .monospaced)).foregroundStyle(Theme.dim)
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
