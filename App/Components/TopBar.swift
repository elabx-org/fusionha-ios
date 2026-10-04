import SwiftUI
import UIKit
import FusionhaKit

/// The web's mobile top bar (TopBar.tsx): logo · search pill · avatar, on a
/// translucent blurred `--bg` with a hairline under it. It slides away while
/// scrolling down and comes back on any upward scroll. On Library the pill
/// filters the grid in place and shows the "This library / Everything" scope
/// bar; on every other tab it opens the full-screen omni search.
struct TopBar: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    private var filtersLibrary: Bool { model.tab == .library && !model.requestScoped }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.scrollToTopTick += 1
            } label: {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle(scale: 0.9))
            .accessibilityLabel("fusionha, scroll to top")

            if filtersLibrary {
                libraryPill
            } else {
                omniPill
            }

            AvatarMenu()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Theme.bg.opacity(0.72)
            }
            .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .animation(.snappy(duration: 0.2), value: focused)
        .onChange(of: model.chromeHidden) { if model.chromeHidden { focused = false } }
        .zIndex(1)
    }

    // MARK: Pills

    private var libraryPill: some View {
        @Bindable var model = model
        return pill(focusedRing: focused) {
            TextField("", text: $model.searchText, prompt: Text("Search").foregroundStyle(Theme.mut))
                .font(.system(size: 16))
                .foregroundStyle(Theme.txt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .onSubmit { focused = false }
            if !model.searchText.isEmpty {
                clearButton { model.searchText = "" }
            }
        }
        .overlay(alignment: .top) {
            if focused {
                ScopeBar(scope: model.searchScope) { scope in
                    if scope == .everything {
                        model.omniQuery = model.searchText
                        focused = false
                        model.showingOmni = true
                    } else {
                        model.searchScope = .library
                    }
                }
                .offset(y: 44 + 6)
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .zIndex(1)
    }

    private var omniPill: some View {
        Button {
            model.omniQuery = ""
            model.showingOmni = true
        } label: {
            pill(focusedRing: false) {
                Text("Search")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.mut)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search")
    }

    private func pill<Content: View>(focusedRing: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.mut)
            content()
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(focusedRing ? Theme.cyan.opacity(0.45) : Theme.line))
        .contentShape(Rectangle())
    }

    private func clearButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.mut)
                .frame(width: 32, height: 32)
                .background(Theme.txt.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear search")
    }
}

/// The scope bar under the focused pill on Library.
private struct ScopeBar: View {
    let scope: SearchScope
    let pick: (SearchScope) -> Void

    var body: some View {
        HStack(spacing: 4) {
            segment("This library", .library)
            segment("Everything", .everything)
        }
        .padding(4)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 10)
    }

    private func segment(_ title: String, _ value: SearchScope) -> some View {
        Button {
            pick(value)
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(scope == value ? Theme.txt : Theme.mut)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(scope == value ? Theme.indigo.opacity(0.22) : .clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - User menu

/// The avatar and its menu (UserMenu.tsx): name + "Administrator", Settings,
/// Reset cache & reload, Log out. The amber dot shows when something needs
/// attention. "Open web app" and the version are iOS-only extras.
struct AvatarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showingSettings = SettingsScreenshot.openAtLaunch

    var body: some View {
        Menu {
            if let me = model.me {
                Section {
                    Button {} label: {
                        Text(me.username)
                        if me.isAdmin { Text("Administrator") }
                    }
                    .disabled(true)
                }
            }
            if model.credentials != nil, !model.requestScoped {
                Section {
                    Button("Settings", systemImage: "slider.horizontal.3") {
                        showingSettings = true
                    }
                }
            }
            Section {
                Button("Reset cache & reload", systemImage: "arrow.clockwise") {
                    Task { await model.resetCacheAndReload() }
                }
            }
            Section {
                Button("Log out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    Task { await model.logOut() }
                }
            }
            Section("Version \(Bundle.main.appVersion) · \(CredentialStore.diagnostics())") {
                if let server = model.credentials?.serverURL {
                    Button("Open web app", systemImage: "safari") { openURL(server) }
                }
            }
        } label: {
            Avatar(me: model.me, size: 32)
                .overlay(alignment: .topTrailing) {
                    if model.attentionCount > 0 && !model.requestScoped {
                        Circle()
                            .fill(Theme.miss)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2).padding(-2))
                            .offset(x: 1, y: -1)
                    }
                }
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .accessibilityLabel(model.attentionCount > 0 ? "Account, \(model.attentionCount) need attention" : "Account")
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView(client: model.client, initialPanel: SettingsScreenshot.panel)
        }
    }
}

/// The 32pt gradient-initials avatar (13/700 white), or the Plex thumb from
/// `GET /api/v1/users/{id}/avatar`, fetched with this device's credentials.
struct Avatar: View {
    @Environment(AppModel.self) private var model
    let me: Me?
    var size: CGFloat = 32
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Theme.fusion)
            if let image {
                Image(uiImage: image).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(me?.initials ?? "")
                    .font(.system(size: size * 13 / 32, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Theme.line))
        .task(id: me?.id) {
            guard let me, me.thumb != nil, let client = model.client else { image = nil; return }
            if let data = try? await client.avatarData(userId: me.id) { image = UIImage(data: data) }
        }
    }
}

// MARK: - Omni search

/// The web's full-screen omni search (OmniSearchOverlay + OmniResults): owned
/// titles first ("In your library", capped at 8), then a TMDB add lane that
/// arms itself when nothing owned matches.
struct OmniSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var armed = false
    @State private var remote: [MediaSearchResult] = []
    @State private var searching = false
    @State private var failed = false
    @State private var searchedTerm = ""
    @FocusState private var focused: Bool

    private var trimmed: String { term.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !trimmed.isEmpty { results }
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            term = model.omniQuery
            focused = true
        }
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
            do {
                remote = try await client.search(term: trimmed, kind: .all)
            } catch {
                if !Task.isCancelled { failed = true; remote = [] }
            }
            searchedTerm = trimmed
            searching = false
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.mut)
            TextField("", text: $term,
                      prompt: Text("Search your library or add something new…").foregroundStyle(Theme.dim))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.txt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .onSubmit { armed = true }
            Button("Cancel") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.i2)
                .buttonStyle(.plain)
        }
        .padding(.top, 14)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
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
                        dismiss()
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
                        dismiss()
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
        } else if failed {
            note("Couldn't reach the metadata provider — try again.")
        } else if remote.isEmpty {
            note("Nothing to add for “\(trimmed)”.")
        } else {
            groupLabel("Available to add · via TMDB", count: remote.count)
            ForEach(remote) { result in
                OmniAddRow(result: result) { dismiss() }
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

/// A TMDB result in the omni add lane: ★ rating, then Add (preview) /
/// Request / Open ↗.
private struct OmniAddRow: View {
    @Environment(AppModel.self) private var model
    let result: MediaSearchResult
    let close: () -> Void
    @State private var requested = false

    var body: some View {
        OmniRow(posterUrl: result.posterUrl,
                dot: result.isAnime ? Theme.kindAnime : (result.kind == .series ? Theme.kindSeries : Theme.kindMovie),
                title: result.title, year: result.year) {
            if let vote = result.voteAverage, vote > 0 {
                Text("★ \(String(format: "%.1f", vote))")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.miss)
            }
        } action: {
            action
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var action: some View {
        if result.inLibrary, let id = result.libraryItemId, !model.requestScoped {
            Button {
                close()
                model.open(id)
            } label: {
                Text("Open ↗").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            .buttonStyle(.plain)
        } else if model.requestScoped {
            iconButton(requested ? "checkmark" : "paperplane", label: "Request") {
                Task {
                    do {
                        try await model.client?.request(MediaRequestCreate(tmdbId: result.tmdbId, kind: result.kind, tier: .hd))
                        requested = true
                        model.toast("Requested \(result.title)")
                    } catch {
                        model.toast("Couldn't request \(result.title)", variant: .error)
                    }
                }
            }
            .disabled(requested || result.inLibrary)
        } else {
            iconButton("plus", label: "Add") {
                close()
                model.openPreview(result)
            }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.fusion, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
        .accessibilityLabel(label)
    }
}

/// An omni row: 44×66 poster, kind dot, title + year, a sub line and a
/// trailing action.
private struct OmniRow<Sub: View, Action: View>: View {
    let posterUrl: String?
    let dot: Color
    let title: String
    let year: Int?
    @ViewBuilder var sub: Sub
    @ViewBuilder var action: Action

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(posterUrl, to: "w92"))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Circle().fill(dot).frame(width: 7, height: 7)
                    (Text(title).foregroundStyle(Theme.txt)
                        + Text(year.map { "  " + String($0) } ?? "").foregroundStyle(Theme.mut).font(.system(size: 13)))
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                sub
            }
            Spacer(minLength: 8)
            action
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct OmniRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.txt.opacity(configuration.isPressed ? 0.05 : 0),
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .padding(.horizontal, 8)
    }
}

/// The "HD·4K" combo pill: only the tiers present, HD purple, 4K cyan.
struct TierComboLabel: View {
    let tiers: [QualityTier]

    var body: some View {
        let hasHD = tiers.contains(.hd) || tiers.isEmpty
        let has4K = tiers.contains(.uhd)
        HStack(spacing: 2) {
            if hasHD { Text("HD").foregroundStyle(Theme.edition) }
            if hasHD && has4K { Text("·").foregroundStyle(Theme.mut) }
            if has4K { Text("4K").foregroundStyle(Theme.grab) }
        }
        .font(.system(size: 10, weight: .bold))
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Theme.panel2, in: Capsule())
    }
}

// MARK: - Shared rows kept for other screens

struct LibraryResultRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w92"))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                HStack(spacing: 6) {
                    if let year = item.year { Text(String(year)) }
                    if item.isAnime == true { AnimeChip() } else { KindGlyph(kind: item.kind) }
                }
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                TierComboLabel(tiers: item.editions.map(\.tier))
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// A TMDB result row with Add (or Request, for requesters) / In library.
struct SearchResultRow: View {
    @Environment(AppModel.self) private var model
    let result: MediaSearchResult
    @State private var requested = false

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w92"))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                HStack(spacing: 6) {
                    if let year = result.year { Text(String(year)) }
                    if result.isAnime { AnimeChip() } else { KindGlyph(kind: result.kind) }
                }
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            action
        }
    }

    @ViewBuilder
    private var action: some View {
        if result.inLibrary, let id = result.libraryItemId, !model.requestScoped {
            Button("Open ↗") { model.open(id) }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .buttonStyle(.plain)
        } else if model.requestScoped {
            Button(requested ? "Requested" : "Request") {
                Task {
                    try? await model.client?.request(MediaRequestCreate(tmdbId: result.tmdbId, kind: result.kind, tier: .hd))
                    requested = true
                }
            }
            .font(.system(size: 13, weight: .bold))
            .buttonStyle(.bordered)
            .tint(Theme.indigo)
            .disabled(requested || result.inLibrary)
        } else {
            Button("Add") { model.addPrefill = result; model.showingAdd = true }
                .font(.system(size: 13, weight: .bold))
                .buttonStyle(.bordered)
                .tint(Theme.indigo)
        }
    }
}

extension Bundle {
    var appVersion: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
