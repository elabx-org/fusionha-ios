import SwiftUI
import FusionhaKit

/// Settings › Access › Users (web `UsersPanel` + `UsersList`): the duplicates
/// banner, the pulse (tinted count chips that filter), the UHD·4K banner and
/// legend, then everyone grouped by role (Administrators, each role,
/// Disabled). Each row carries its UHD·4K chip and its Plex watchlist and
/// Letterboxd chips; "Show" filters by source. Tap a person to edit them.
/// Needs Manage users; merging and disconnecting a provider need full admin.
struct UsersSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var users: [UserAccount]?
    @State private var roles: [RoleDetail] = []
    @State private var error: String?
    @State private var editing: UserAccount?
    @State private var adding = false
    @State private var show: UsersShowFilter = .all
    @State private var pulse: UsersRoster.PulseKey?
    @State private var collapsed: Set<String> = []
    @State private var plex: [Int: PlexWatchlistSummaryRow] = [:]
    @State private var letterboxd: [Int: LetterboxdSummaryRow] = [:]
    @State private var uhd: [Int: UserTierAccess] = [:]
    @State private var uhdBanner: UsersUHD.Banner?
    @State private var duplicates: [DuplicateGroup] = []
    @State private var merging: DuplicateGroup?
    @State private var disconnecting = false
    @State private var query = ""

    private var canAdminSystem: Bool { model.me?.has("system.admin") == true }

    var body: some View {
        SettingsForm(slug: "access") {
            if let error {
                SettingsLoadingRow(error: error)
            } else if let users {
                header(users)
                list(users)
                if canAdminSystem {
                    Section {
                        Button("Disconnect a sign-in provider…", systemImage: "person.badge.minus") { disconnecting = true }
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
        .searchable(text: $query, prompt: "Search users, roles, sign-in methods…")
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: show) { if show != .all { pulse = nil } }
        .onChange(of: pulse) { if pulse != nil { show = .all } }
        .sheet(item: $editing) { u in UserEditorSheet(user: u, roles: roles) { await load() } }
        .sheet(isPresented: $adding) { NewUserSheet(roles: roles) { await load() } }
        .sheet(item: $merging) { g in MergeUsersSheet(group: g) { await load() } }
        .sheet(isPresented: $disconnecting) { DisconnectProviderSheet { await load() } }
    }

    @ViewBuilder private func header(_ users: [UserAccount]) -> some View {
        if !duplicates.isEmpty {
            Section {
                UsersDuplicatesBanner(groups: duplicates, canMerge: canAdminSystem) { merging = duplicates.first }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        Section {
            UsersPulseView(users: users, selection: $pulse)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        if let uhdBanner {
            Section { UsersUhdBanner(state: uhdBanner) }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
        Section {
            Picker("Show", selection: $show) {
                ForEach(UsersShowFilter.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } footer: {
            if !uhd.isEmpty { UsersUhdLegend().padding(.top, 6) }
        }
    }

    @ViewBuilder private func list(_ users: [UserAccount]) -> some View {
        let visible = users.filter {
            show.passes($0, plex: plex[$0.id], letterboxd: letterboxd[$0.id]) && (pulse?.passes($0) ?? true)
                && UsersRoster.matches($0, query: query)
        }
        if visible.isEmpty {
            Section { Text(query.isEmpty ? "No users match this filter." : "No users match “\(query.trimmingCharacters(in: .whitespaces))”.").foregroundStyle(Theme.mut) }
        }
        ForEach(UsersRoster.groups(visible)) { group in
            let isCollapsed = collapsed.contains(group.id)
            Section {
                if !isCollapsed {
                    ForEach(group.users) { u in
                        Button { editing = u } label: {
                            UsersListRow(user: u, plex: plex[u.id], letterboxd: letterboxd[u.id], uhd: uhd[u.id])
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                UsersGroupHeader(group: group, collapsed: isCollapsed) {
                    if isCollapsed { collapsed.remove(group.id) } else { collapsed.insert(group.id) }
                }
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            users = try await client.userAccounts()
            roles = (try? await client.roleDetails()) ?? roles
            error = nil
            async let plexRows = try? client.plexWatchlistSummary()
            async let lbRows = try? client.letterboxdSummary()
            async let tierRows = try? client.plexTierAccess()
            async let preview = try? client.plexAccessPreview()
            async let dupes = try? client.userDuplicates()
            plex = Dictionary((await plexRows ?? []).map { ($0.userId, $0) }, uniquingKeysWith: { a, _ in a })
            letterboxd = Dictionary((await lbRows ?? []).map { ($0.userId, $0) }, uniquingKeysWith: { a, _ in a })
            uhd = Dictionary((await tierRows ?? []).map { ($0.userId, $0) }, uniquingKeysWith: { a, _ in a })
            uhdBanner = UsersUHD.banner(await preview)
            duplicates = (await dupes ?? []).filter { $0.members.count >= 2 }
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the users. Managing users needs Manage users.")
        }
    }
}
