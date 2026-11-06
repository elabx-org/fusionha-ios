import SwiftUI
import FusionhaKit

// The unified search's rows (the web's omni rows): poster, title, then
// "● 2024 · Movie" with an optional source tag, the tier pill (owned) or
// ★ rating (add), and the trailing actions. Rows are solid content; only the
// field, scopes and menus are glass.

struct SearchRow<Tag: View, Accessory: View, Actions: View>: View {
    let posterUrl: String?
    let dot: Color
    let title: String
    let meta: String
    var picked = false
    /// A third line under the meta line (v2: the owned title's tickets).
    var footer: AnyView? = nil
    @Environment(\.pagePalette) private var page
    @ViewBuilder var tag: Tag
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(posterUrl, to: "w154"))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BrowseInks(page: page).ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 7, height: 7)
                    Text(meta).font(.system(size: 12.5)).foregroundStyle(BrowseInks(page: page).muted).lineLimit(1)
                    tag
                }
                if let footer { footer.padding(.top, 1) }
            }
            Spacer(minLength: 8)
            accessory
            actions
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 9)
        .background(picked ? Theme.i2.opacity(0.12) : .clear)
        .contentShape(Rectangle())
    }
}

enum SearchRowText {
    /// "2024 · Movie", the year optional.
    static func meta(year: Int?, kind: String) -> String {
        [year.map { String($0) }, kind].compactMap { $0 }.joined(separator: " · ")
    }
}

/// A row's trailing action: Open (chevron), Add (filled +) or Request (person).
/// 30 pt visible, 44 pt to hit.
struct SearchRowButton: View {
    enum Kind { case open, add, request }
    let kind: Kind
    let action: () -> Void
    /// v2 (S11): Add is a "+ Add" capsule, as in the mock, where the
    /// column has room (a narrow Duo column keeps the round +).
    @Environment(\.browseLook) private var look
    @Environment(\.paneSize) private var pane

    var body: some View {
        if look != nil && kind == .add && pane.width >= 360 {
            Button(action: action) {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Theme.primary.opacity(0.16), in: Capsule())
                    .frame(minHeight: 44)
                    .padding(.trailing, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle(scale: 0.94))
        } else if look != nil && kind == .open {
            // The row itself opens; the chevron only says so.
            Button(action: action) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        } else {
            circle
        }
    }

    private var circle: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(kind == .add ? Theme.onAccent : (kind == .open ? Theme.i2 : Theme.txt))
                .frame(width: 32, height: 32)
                .background(kind == .add ? Theme.primary : Theme.panel2, in: Circle())
                .frame(width: 42, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
        .accessibilityLabel(label)
    }

    private var symbol: String {
        switch kind {
        case .open: return "chevron.right"
        case .add: return "plus"
        case .request: return "person"
        }
    }

    private var label: String {
        switch kind {
        case .open: return "Open"
        case .add: return "Add"
        case .request: return "Request"
        }
    }
}

/// The row press: a faint wash, no scale (the list is content).
struct SearchRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.txt.opacity(configuration.isPressed ? 0.05 : 0))
    }
}

/// A lane's rows in one solid card, hairlines between them.
struct SearchLaneCard<Content: View>: View {
    @Environment(\.browseLook) private var look
    @Environment(\.pagePalette) private var page
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        Rectangle().fill(page.map { $0.ink.opacity(0.09) } ?? Theme.line)
                            .frame(height: 1).padding(.leading, 68)
                    }
                    row
                }
            }
        }
        .browseCard(look, radius: look == nil ? Theme.radiusLg : 20)
        .padding(.horizontal, Theme.pageGutter)
    }
}

/// "In your library": opens the title. No provider mark (option A).
struct SearchOwnedRow: View {
    @Environment(AppModel.self) private var model
    /// v2 (S11): the HD and 4K tickets under the meta line, no tier label.
    @Environment(\.browseLook) private var look
    let item: MediaItem

    var body: some View {
        Button { model.open(item.id) } label: {
            SearchRow(posterUrl: item.posterUrl, dot: Theme.kind(item.kindBucket), title: item.title,
                      meta: SearchRowText.meta(year: item.year, kind: kindName),
                      picked: model.presentedItem?.id == item.id, footer: look?.tickets(item)) {
                EmptyView()
            } accessory: {
                if look == nil { TierComboLabel(tiers: item.editions.map(\.tier)) }
            } actions: {
                SearchRowButton(kind: .open) { model.open(item.id) }
            }
        }
        .buttonStyle(SearchRowStyle())
    }

    private var kindName: String {
        switch item.kindBucket {
        case .movie: return "Movie"
        case .series: return "Series"
        case .anime: return "Anime"
        }
    }
}
