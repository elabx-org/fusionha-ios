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
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 7, height: 7)
                    Text(meta).font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(1)
                    tag
                }
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

    var body: some View {
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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 68) }
                    row
                }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
        .padding(.horizontal, Theme.pageGutter)
    }
}

/// "In your library": opens the title. No provider mark (option A).
struct SearchOwnedRow: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem

    var body: some View {
        Button { model.open(item.id) } label: {
            SearchRow(posterUrl: item.posterUrl, dot: Theme.kind(item.kindBucket), title: item.title,
                      meta: SearchRowText.meta(year: item.year, kind: kindName),
                      picked: model.presentedItem?.id == item.id) {
                EmptyView()
            } accessory: {
                TierComboLabel(tiers: item.editions.map(\.tier))
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
