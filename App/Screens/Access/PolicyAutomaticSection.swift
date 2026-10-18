import SwiftUI
import FusionhaKit

/// The request policy's "Automatic requests" (web `PolicyWatchlistField` +
/// `PolicyLinkListsField`, fusionha 0.4.209 / 0.4.213): the Plex watchlist
/// grant, the Letterboxd & linked lists grant and the per-person "Max linked
/// lists" (1–20, default 5). A person inherits or overrides each grant; a
/// role switches it for its members. A non-admin can only grant what they
/// hold themselves (the server answers 403 `amplification`).
struct PolicyAutomaticSection: View {
    let policy: RequestPolicy
    let isUser: Bool
    let save: ([String: SettingsJSON]) -> Void

    private static let plexKey = "auto_request_plex_watchlist"
    private static let linkKey = "can_link_lists"
    private static let maxKey = "max_linked_lists"

    var body: some View {
        let linkAllowed = policy.canLinkLists ?? policy.effective?.canLinkLists ?? false
        let maxLists = min(20, max(1, policy.maxLinkedLists ?? policy.effective?.maxLinkedLists ?? 5))
        Section {
            grant("Auto-request from Plex watchlist", key: Self.plexKey, stored: policy.autoRequestPlexWatchlist,
                  effective: policy.effective?.autoRequestPlexWatchlist ?? false)
            grant("Letterboxd & linked lists", key: Self.linkKey, stored: policy.canLinkLists,
                  effective: policy.effective?.canLinkLists ?? false)
            Stepper(value: Binding(get: { maxLists }, set: { save([Self.maxKey: .int(min(20, max(1, $0)))]) }), in: 1...20) {
                LabeledContent("Max linked lists", value: "\(maxLists)")
            }
            .disabled(!linkAllowed)
        } header: {
            Text("Automatic requests")
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        let who = isUser ? "this person’s" : "this role’s members’"
        return "Lets \(who) Plex watchlist and lists, Letterboxd diary, own watchlist, linked lists and followed watchlists create requests on their own. Nothing happens until they turn it on in their Account, and approval still needs an auto-approve or a Watchlists & lists rule. Lists and followed watchlists count toward the limit; lowering it never removes lists already linked. A non-admin can only grant this if they hold it themselves."
    }

    @ViewBuilder
    private func grant(_ title: String, key: String, stored: Bool?, effective: Bool) -> some View {
        if isUser {
            Picker(title, selection: Binding(get: { stored.map { $0 ? 1 : 0 } ?? -1 },
                                              set: { v in save([key: v < 0 ? .null : .bool(v == 1)]) })) {
                Text("Inherit · \(policy.flagLine(key, on: effective))").tag(-1)
                Text("Allowed").tag(1)
                Text("Not allowed").tag(0)
            }
        } else {
            Toggle(title, isOn: Binding(get: { stored ?? effective }, set: { save([key: .bool($0)]) })).tint(Theme.i1)
        }
    }
}
