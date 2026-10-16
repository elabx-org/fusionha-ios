import SwiftUI
import FusionhaKit

/// "Signed-in devices" (web `AccountSessionsDialog`): every live session of
/// an account, newest activity first, with Sign out per device and, for your
/// own account, Sign out other devices. `userId` nil = you. Signing out never
/// disables the account or its API tokens (this app keeps working).
struct AccountSessionsSheet: View {
    var userId: Int? = nil
    var title = "Signed-in devices"
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [AccountSession]?
    @State private var error: String?
    @State private var busy: Set<String> = []
    @State private var revokingOthers = false

    private var targetId: Int? { userId ?? model.me?.id }
    private var isSelf: Bool { userId == nil || userId == model.me?.id }

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Text(error).foregroundStyle(Theme.danger)
                } else if let sessions {
                    if sessions.isEmpty {
                        Text("No browser sessions. This app signs in with its own token, which isn’t listed here.")
                            .foregroundStyle(Theme.mut)
                    }
                    ForEach(sessions) { s in row(s) }
                } else {
                    ProgressView()
                }
                if isSelf, let sessions, sessions.contains(where: { $0.current != true }) {
                    Section {
                        Button(revokingOthers ? "Signing out…" : "Sign out other devices", systemImage: "rectangle.portrait.and.arrow.right",
                               role: .destructive) { Task { await revokeOthers() } }
                            .disabled(revokingOthers)
                    } footer: {
                        Text("Your API tokens, including this app’s, keep working.")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
            .refreshable { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ s: AccountSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: s.symbol).font(.system(size: 18)).foregroundStyle(Theme.mut).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(s.device).font(.subheadline.weight(.semibold))
                    if s.current == true { Text("This device").font(.caption.weight(.bold)).foregroundStyle(Theme.done) }
                }
                Text([s.ip, s.via == "device_token" ? "via API token" : nil,
                      ServerTime.parse(s.lastSeenAt).map { "active \($0.formatted(.relative(presentation: .named)))" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            if s.current != true {
                Button("Sign out") { Task { await revoke(s) } }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .disabled(busy.contains(s.id))
            }
        }
    }

    private func load() async {
        guard let client = model.client, let id = targetId else { return }
        do {
            let list = isSelf ? try await client.mySessions() : try await client.userSessions(userId: id)
            sessions = list.sorted { ($0.lastSeenAt ?? "") > ($1.lastSeenAt ?? "") }
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the sessions.")
        }
    }

    private func revoke(_ s: AccountSession) async {
        guard let client = model.client, let id = targetId else { return }
        busy.insert(s.id)
        defer { busy.remove(s.id) }
        do { try await client.revokeSession(userId: id, sessionId: s.id) } catch {
            model.toast(ErrorCopy.message(for: error), title: "Couldn’t sign out", variant: .error)
        }
        await load()
    }

    private func revokeOthers() async {
        guard let client = model.client else { return }
        revokingOthers = true
        defer { revokingOthers = false }
        do {
            let n = try await client.revokeMyOtherSessions()
            model.toast(n == 1 ? "Signed out 1 device" : "Signed out \(n) devices")
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Couldn’t sign out", variant: .error)
        }
        await load()
    }
}
