import SwiftUI
import FusionhaKit

/// v2 Account's head (mock requests.js `acctHead`): the large avatar, the
/// name, and "Admin · media.example.com" with a connected dot.
struct V2AccountHead: View {
    let me: Me
    let server: URL?
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 14) {
            AccountAvatar(me: me, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(me.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(Theme.done).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(line).font(.subheadline).foregroundStyle(Theme.mut).lineLimit(1)
                    UnencryptedMark(server: server)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var line: String {
        let role = me.accountRoleName ?? me.roleLabel
        guard let host = server?.host else { return role }
        return "\(role) · \(host)"
    }
}

/// The version footer (mock: "Build 725 · server 0.4.237 · Widget
/// diagnostics"): the app build and the server's version from `/health`.
/// Touch and hold shows the keychain and App Group diagnostics, as the v1 hub did.
struct V2AccountVersionFooter: View {
    @Environment(AppModel.self) private var model
    @State private var server: String?
    @State private var showingDiagnostics = false

    var body: some View {
        VStack(spacing: 4) {
            Text("fusionha \(Bundle.main.appVersion)" + (server.map { " · server \($0)" } ?? ""))
            if showingDiagnostics, !model.avatar.diagnostics.isEmpty {
                Text(model.avatar.diagnostics).font(.caption.monospaced()).textSelection(.enabled)
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.dim)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onLongPressGesture { withAnimation(.snappy) { showingDiagnostics.toggle() } }
        .accessibilityHint("Touch and hold for diagnostics")
        .task { server = try? await model.client?.health().version }
    }
}
