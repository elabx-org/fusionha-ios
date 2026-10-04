import SwiftUI
import FusionhaKit

/// Requester "You" tab (`routes/Account.tsx`): a centred profile block (role
/// avatar, name, role badge), then rows for requests made, sign-in methods,
/// reset cache, and Sign out.
struct YouView: View {
    @Environment(AppModel.self) private var model
    @State private var requestCount = 0
    @State private var webPage: URL?

    private var me: Me? { model.me }

    var body: some View {
        Screen {
            ScrollView {
                VStack(spacing: 0) {
                    profile.discoverReveal(index: 0, step: 0.05)
                    row {
                        HStack {
                            Text("Requests made").foregroundStyle(Theme.txt)
                            Spacer()
                            Text("\(requestCount)").font(.system(size: 13.5, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Theme.dim)
                        }
                    }
                    .discoverReveal(index: 1, step: 0.05)
                    actionRow("Sign-in methods") {
                        if let server = model.credentials?.serverURL {
                            webPage = server.appendingPathComponent("account")
                        }
                    }
                    .discoverReveal(index: 2, step: 0.05)
                    actionRow("Reset cache & reload") { Task { await resetCache() } }
                        .discoverReveal(index: 3, step: 0.05)
                    row {
                        Button("Sign out") { Task { await signOut() } }
                            .buttonStyle(.discover(.danger, fullWidth: true))
                    }
                    .discoverReveal(index: 4, step: 0.05)
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 90)
                .frame(maxWidth: .infinity)
            }
        }
        .discoverToastOverlay()
        .sheet(item: $webPage) { SafariView(url: $0).ignoresSafeArea() }
        .task(id: me?.id) {
            requestCount = (try? await model.client?.requests(status: nil).count) ?? 0
        }
    }

    // MARK: Profile

    private var role: String {
        if me?.isAdmin == true { return "admin" }
        return (me?.roleName ?? "").lowercased()
    }

    private var roleLabel: String {
        if me?.isAdmin == true { return "Admin" }
        return me?.roleName ?? "No role"
    }

    private var displayName: String {
        guard let me else { return "" }
        if me.username.range(of: #"\(plex:\d+\)$"#, options: .regularExpression) != nil, let plex = me.plexUsername {
            return plex
        }
        return me.username
    }

    private var avatarFill: AnyShapeStyle {
        switch role {
        case "admin":
            return AnyShapeStyle(LinearGradient(colors: [Theme.indigo.opacity(0.7), Theme.indigo],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case "manager":
            return AnyShapeStyle(LinearGradient(colors: [Theme.cyan, Color(hex: 0x1894A7)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case "requestor", "requester":
            return AnyShapeStyle(LinearGradient(colors: [Theme.miss, Color(hex: 0xAC6F08)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            return AnyShapeStyle(Theme.panel2)
        }
    }

    private var roleColors: (Color, Color) {
        switch role {
        case "admin": return (Theme.indigo, Theme.indigo.opacity(0.16))
        case "manager": return (Theme.cyan, Theme.cyan.opacity(0.15))
        case "requestor", "requester": return (Theme.miss, Theme.miss.opacity(0.16))
        default: return (Theme.mut, Theme.panel2)
        }
    }

    private var initials: String {
        let name = displayName
        let parts = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" || $0 == "-" })
        let letters = parts.count >= 2 ? parts.prefix(2).compactMap(\.first) : Array(name.prefix(2))
        return String(letters).uppercased()
    }

    private var profile: some View {
        let (fg, bg) = roleColors
        let plain = !["admin", "manager", "requestor", "requester"].contains(role)
        return VStack(spacing: 8) {
            ZStack {
                Circle().fill(avatarFill)
                Text(initials).font(.system(size: 24, weight: .bold)).foregroundStyle(plain ? Theme.mut : .white)
                if me?.thumb != nil, let me, let server = model.credentials?.serverURL {
                    DiscoverArt(url: server.appendingPathComponent("api/v1/users/\(me.id)/avatar"))
                        .clipShape(Circle())
                }
            }
            .frame(width: 74, height: 74)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.55), radius: 14, y: 10)
            Text(displayName).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt)
                .padding(.top, 4)
            HStack(spacing: 5) {
                Circle().fill(fg).frame(width: 6, height: 6)
                Text(roleLabel).font(.system(size: 10.5, weight: .bold))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(bg, in: Capsule())
        }
        .padding(.top, 10)
        .padding(.bottom, 26)
    }

    // MARK: Rows

    private func row<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .font(.system(size: 13.5))
            .padding(.horizontal, 15).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel(Theme.card, radius: 11)
            .padding(.top, 10)
    }

    private func actionRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .padding(.horizontal, 15).padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel(Theme.card, radius: 11)
                .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .padding(.top, 10)
    }

    // MARK: Actions

    private func resetCache() async {
        URLCache.shared.removeAllCachedResponses()
        await model.loadMe()
        await model.loadLibrary()
        requestCount = (try? await model.client?.requests(status: nil).count) ?? requestCount
        DiscoverToasts.shared.show(.info, "Cache cleared and reloaded.")
    }

    private func signOut() async {
        // End the session and revoke this device's token, like the web's logout.
        await model.logOut()
    }
}

/// Press state for full-width rows: text turns cyan, like the web's `:active`.
private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.cyan : Theme.txt)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
