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
            Section {
                Button("Add user", systemImage: "person.badge.plus") { adding = true }
            }
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
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { u in UserEditorSheet(user: u, roles: roles) { await load() } }
        .sheet(isPresented: $adding) { NewUserSheet(roles: roles) { await load() } }
    }

    private func row(_ u: UserAccount) -> some View {
        HStack(spacing: 12) {
            Image(systemName: u.isAdmin ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                .font(.system(size: 22)).foregroundStyle(u.isActive == false ? Theme.dim : Theme.i2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(u.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                    if u.authProvider == "plex" { Text("Plex").font(.caption2.weight(.bold)).foregroundStyle(Theme.miss) }
                    if u.isActive == false { Text("Disabled").font(.caption2.weight(.bold)).foregroundStyle(Theme.danger) }
                }
                Text([u.isAdmin ? "Admin" : (u.roleName ?? "No role"),
                      (u.activeSessionCount ?? 0) > 0 ? "\(u.activeSessionCount ?? 0) active \((u.activeSessionCount ?? 0) == 1 ? "session" : "sessions")" : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.mut)
                UserSourceChips(plex: plex[u.id], letterboxd: letterboxd[u.id])
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.dim)
        }
        .contentShape(Rectangle())
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
