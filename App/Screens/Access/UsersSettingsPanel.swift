import SwiftUI
import FusionhaKit

/// Settings › Access › Users (web `UsersPanel`): every account with its role,
/// sign-in source, live sessions and whether it is disabled; add an account;
/// tap one to rename, change its role, disable it, sign it out, open its
/// request policy or delete it. Each row carries its Plex watchlist and
/// Letterboxd chips, and "Show" filters by source (fusionha 0.4.209 /
/// 0.4.213). Needs Manage users.
struct UsersSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var users: [UserAccount]?
    @State private var roles: [RoleDetail] = []
    @State private var error: String?
    @State private var editing: UserAccount?
    @State private var adding = false
    @State private var show: UsersShowFilter = .all
    @State private var plex: [Int: PlexWatchlistSummaryRow] = [:]
    @State private var letterboxd: [Int: LetterboxdSummaryRow] = [:]

    var body: some View {
        SettingsForm(slug: "access") {
            if let error {
                SettingsLoadingRow(error: error)
            } else if let users {
                let visible = users.filter { show.passes($0, plex: plex[$0.id], letterboxd: letterboxd[$0.id]) }
                Section {
                    Picker("Show", selection: $show) {
                        ForEach(UsersShowFilter.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section("\(visible.count) \(visible.count == 1 ? "account" : "accounts")") {
                    ForEach(visible) { u in
                        Button { editing = u } label: { row(u) }.buttonStyle(.plain)
                    }
                }
            } else {
                SettingsLoadingRow()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add user", systemImage: "plus") { adding = true }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { u in UserEditorSheet(user: u, roles: roles) { await load() } }
        .sheet(isPresented: $adding) { NewUserSheet(roles: roles) { await load() } }
    }

    /// The person's avatar, name and tags, "Admin · 2 active sessions · 23
    /// auto-requested", then one pill per automatic source.
    private func row(_ u: UserAccount) -> some View {
        let sessions = u.activeSessionCount ?? 0
        let meta = [u.isAdmin ? "Admin" : (u.roleName ?? "No role"),
                    sessions > 0 ? "\(sessions) \(sessions == 1 ? "session" : "sessions")" : nil,
                    UserSourceChips.requestedLine(plex: plex[u.id], letterboxd: letterboxd[u.id])]
        return HStack(alignment: .top, spacing: 12) {
            PersonAvatar(userId: u.id, name: u.displayName, hasThumb: u.thumb != nil)
                .opacity(u.isActive == false ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(u.displayName).font(.system(size: 16, weight: .semibold)).foregroundStyle(u.isActive == false ? Theme.dim : Theme.txt)
                    if u.authProvider == "plex" { tag("Plex", Theme.mut) }
                    if u.isActive == false { tag("Disabled", Theme.danger) }
                }
                Text(meta.compactMap { $0 }.joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(Theme.mut)
                UserSourceChips(plex: plex[u.id], letterboxd: letterboxd[u.id])
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
                .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func tag(_ word: String, _ color: Color) -> some View {
        Text(word).font(.system(size: 11, weight: .bold)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            users = try await client.userAccounts()
            roles = (try? await client.roleDetails()) ?? roles
            error = nil
            async let plexRows = try? client.plexWatchlistSummary()
            async let lbRows = try? client.letterboxdSummary()
            plex = Dictionary((await plexRows ?? []).map { ($0.userId, $0) }, uniquingKeysWith: { a, _ in a })
            letterboxd = Dictionary((await lbRows ?? []).map { ($0.userId, $0) }, uniquingKeysWith: { a, _ in a })
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the users. Managing users needs Manage users.")
        }
    }
}
