import SwiftUI
import FusionhaKit

/// The web's mobile top bar: brand mark, the search pill (scoped to "This
/// library" or "Everything" while focused) and the avatar menu.
struct TopBar: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 10) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .accessibilityLabel("fusionha")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.mut)
                TextField("", text: $model.searchText, prompt: Text("Search").foregroundStyle(Theme.mut))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.txt)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.mut)
                            .frame(width: 28, height: 28)
                            .background(Theme.txt.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(height: 44)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(focused ? Theme.cyan.opacity(0.45) : Theme.line))
            .overlay(alignment: .bottom) {
                if focused && !model.requestScoped {
                    ScopeBar(scope: $model.searchScope)
                        .offset(y: 46)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .zIndex(1)

            AvatarMenu()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.bg)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .animation(.snappy(duration: 0.2), value: focused)
        .zIndex(1)
    }
}

private struct ScopeBar: View {
    @Binding var scope: SearchScope

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
            scope = value
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(scope == value ? Theme.txt : Theme.mut)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(scope == value ? Theme.indigo.opacity(0.3) : .clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The gradient initials avatar and its menu (name + role, Settings, Log out).
struct AvatarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showingSettings = SettingsScreenshot.openAtLaunch

    var body: some View {
        Menu {
            Section(model.me.map { "\($0.username) · \($0.roleLabel)" } ?? "") {
                if let server = model.credentials?.serverURL {
                    if !model.requestScoped {
                        Button("Settings", systemImage: "slider.horizontal.3") {
                            showingSettings = true
                        }
                    }
                    Button("Open web app", systemImage: "safari") { openURL(server) }
                }
            }
            Button("Log out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                model.signOut()
            }
            Section("Version \(Bundle.main.appVersion) · \(CredentialStore.diagnostics())") {}
        } label: {
            Avatar(me: model.me, size: 38)
        }
        .accessibilityLabel("Account")
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView(client: model.client, initialPanel: SettingsScreenshot.panel)
        }
    }
}

struct Avatar: View {
    let me: Me?
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Theme.indigo, Theme.cyan],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            if let thumb = me?.thumb, let url = URL(string: thumb) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initials
                }
                .clipShape(Circle())
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.white.opacity(0.18)))
    }

    private var initials: some View {
        Text(me?.initials ?? "")
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(.white)
    }
}

/// Top-bar search results: library matches, plus TMDB titles for "Everything".
struct OmniSearchResults: View {
    @Environment(AppModel.self) private var model
    @State private var remote: [MediaSearchResult] = []
    @State private var searching = false

    private var query: String { model.searchText.trimmingCharacters(in: .whitespaces) }

    private var libraryMatches: [MediaItem] {
        model.library.filter { $0.title.localizedCaseInsensitiveContains(query) }.prefix(12).map { $0 }
    }

    private var includeRemote: Bool { model.searchScope == .everything || model.requestScoped }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !model.requestScoped {
                    EyebrowLabel(text: "In your library")
                    if libraryMatches.isEmpty {
                        Text("No library titles match “\(query)”.")
                            .font(.system(size: 14)).foregroundStyle(Theme.mut)
                    }
                    ForEach(libraryMatches) { item in
                        Button { model.open(item.id) } label: { LibraryResultRow(item: item) }
                            .buttonStyle(.plain)
                    }
                }
                if includeRemote {
                    HStack {
                        EyebrowLabel(text: model.requestScoped ? "Titles" : "Add to library")
                        if searching { ProgressView().controlSize(.small) }
                    }
                    ForEach(remote) { result in
                        SearchResultRow(result: result)
                    }
                    if !searching && remote.isEmpty {
                        Text("Nothing found on TMDB.").font(.system(size: 14)).foregroundStyle(Theme.mut)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.immediately)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .task(id: "\(query)|\(includeRemote)") {
            if model.library.isEmpty && !model.requestScoped { await model.loadLibrary() }
            guard includeRemote, query.count >= 2 else { remote = []; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let client = model.client else { return }
            searching = true
            remote = (try? await client.search(term: query, kind: .all)) ?? []
            searching = false
        }
    }
}

struct LibraryResultRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w92"))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                HStack(spacing: 6) {
                    if let year = item.year { Text(String(year)) }
                    if item.isAnime == true { AnimeChip() } else { KindGlyph(kind: item.kind) }
                }
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                HStack(spacing: 4) { ForEach(item.editions) { TierPill(tier: $0.tier) } }
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
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
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
            Button("In library") { model.open(id) }
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Theme.done)
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
