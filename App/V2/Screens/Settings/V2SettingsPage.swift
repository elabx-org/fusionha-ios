import SwiftUI

/// A rebuilt S1 panel page (Download Clients, Indexers): the page header
/// with the section tile, then the panel's cards on the section-tinted
/// ground, with the v1 panels' toasts, delete confirms and pull to refresh.
/// The bar's inline title fades in once the header scrolls away.
struct V2SettingsPage<Content: View>: View {
    let slug: String
    var subtitle: String?
    var toaster: FetchToaster
    @Binding var confirm: FetchConfirm?
    var refresh: (() async -> Void)?
    @ViewBuilder var content: Content
    @State private var headerGone = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                V2SettingsPageHeader(slug: slug, subtitle: subtitle)
                    .padding(.bottom, 14)
                    .settingsReveal()
                content
            }
            .padding(.horizontal, Theme.pageGutter)
            .padding(.top, 6)
            .padding(.bottom, 64)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .v2SettingsHeaderWatch($headerGone)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await refresh?() }
        .v2SettingsChrome(slug: slug, titleShown: headerGone, toaster: toaster, confirm: $confirm)
    }
}

extension View {
    /// Marks the page header gone once this scroll view has scrolled past it.
    func v2SettingsHeaderWatch(_ gone: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > 52
        } action: { _, isGone in
            gone.wrappedValue = isGone
        }
    }

    /// A rebuilt panel's chrome: the inline bar title (shown once the page
    /// header has scrolled away), toasts, delete confirms, the pane size
    /// v1's panels read, and the section-tinted ground.
    func v2SettingsChrome(slug: String, titleShown: Bool, toaster: FetchToaster,
                          confirm: Binding<FetchConfirm?>) -> some View {
        let title = SettingsNav.panel(slug)?.title ?? slug
        return settingsLayout()
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .opacity(titleShown ? 1 : 0)
                        .accessibilityHidden(!titleShown)
                }
            }
            .fetchToasts(toaster)
            .fetchConfirm(confirm)
            .v2SettingsGround(slug)
    }
}

/// The S1 page header (mock `pgHead` / `HDR`): the panel's tile at 46pt
/// beside its title and a one-line subtitle.
struct V2SettingsPageHeader: View {
    let slug: String
    var subtitle: String?
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 14) {
            V2SettingsTile(id: slug, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(SettingsNav.panel(slug)?.title ?? slug)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                if let line = subtitle ?? SettingsNav.panel(slug)?.subtitle, !line.isEmpty {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

/// A small section header above a group of cards (mock `.sech`): muted,
/// semibold, inset to the card's text.
struct V2SettingsGroupHeader: View {
    let title: String
    var trailing: String?
    var top: CGFloat = 22
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.footnote)
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, top)
        .padding(.bottom, 8)
    }
}

/// The hairline between rows on a W1 card, inset by `leading`.
struct V2SettingsHairline: View {
    var leading: CGFloat = 16
    @Environment(\.pagePalette) private var page
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ModuleMetrics.hairline(light: page?.isLight ?? Theme.isLight)
            .frame(height: EditionChip.hairline(displayScale))
            .padding(.leading, leading)
    }
}
