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
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
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
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w154"))
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
        if result.inLibrary, let id = model.libraryItemId(for: result), !model.requestScoped {
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

