import SwiftUI
import FusionhaKit

/// The lede under "Watchlists & lists" on v2 (approved mock `rq-lists`):
/// what the page is for, and that pulling down syncs. A plain list row on the
/// page ground, not a card.
struct V2WatchlistsLede: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(AutomaticRequestsCopy.sub)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
                Label {
                    Text("Pull down to sync").fontWeight(.semibold).foregroundStyle(Theme.txt)
                } icon: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(Theme.mut)
                }
                .font(.system(size: 13))
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
            .listRowBackground(Color.clear)
        }
    }
}

/// "Lists you follow" with none followed yet: a dashed placeholder naming
/// the sites a public list can come from, opening Follow.
struct V2FollowListPlaceholder: View {
    let onFollow: () -> Void

    var body: some View {
        Section {
            Button(action: onFollow) {
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        ProviderTile(provider: .mdblist, size: 26)
                        ProviderTile(provider: .trakt, size: 26)
                        ProviderTile(provider: .letterboxd, size: 26)
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AutomaticRequestsCopy.follow).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                        Text("Paste an MDBList, Trakt or Letterboxd address.")
                            .font(.system(size: 13)).foregroundStyle(Theme.mut)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("Lists you follow")
        }
    }
}
