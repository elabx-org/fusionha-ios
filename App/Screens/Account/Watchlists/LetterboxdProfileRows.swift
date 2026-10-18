import SwiftUI
import FusionhaKit

/// "Your Letterboxd" (web `LetterboxdProfile`): the connect field, the
/// connected row with Change / Disconnect, and the can't-read state. A good
/// connect opens the diary choice (`diaryChoosing`).
struct LetterboxdProfileRows: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let read: LetterboxdRead
    @Binding var diaryChoosing: Bool
    @State private var editing = false
    @State private var typing = ""
    @State private var askingDisconnect = false

    var body: some View {
        if let user = read.username, !editing {
            if read.profileError != nil {
                problemRows(user)
            } else {
                connectedRow(user)
            }
        } else {
            connectRows
        }
    }

    // MARK: Connect

    @ViewBuilder
    private var connectRows: some View {
        let bad = !typing.isEmpty && !LetterboxdLogic.validUsername(typing)
        Text("Request films as you log them. fusionha reads only what is **public** on your profile. It can’t post, rate or change anything, and it never asks for your Letterboxd password.")
            .font(.footnote).foregroundStyle(Theme.mut)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text("letterboxd.com/").foregroundStyle(Theme.dim)
                TextField("username", text: $typing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .submitLabel(.go)
                    .onSubmit { if LetterboxdLogic.validUsername(typing) { connect(typing) } }
                    .onChange(of: typing) { _, text in
                        let trimmed = String(text.trimmingCharacters(in: .whitespaces).prefix(15))
                        if trimmed != text { typing = trimmed }
                    }
                    .accessibilityLabel("Letterboxd username")
            }
            Text(bad ? "2 to 15 letters, numbers or underscores." : "Letters, numbers and underscores, 2 to 15. fusionha builds the address itself from this name.")
                .font(.caption).foregroundStyle(bad ? Theme.danger : Theme.mut)
        }
        HStack(spacing: 10) {
            Button { connect(typing) } label: {
                if store.letterboxdBusy {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
                } else {
                    Text("Connect")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!LetterboxdLogic.validUsername(typing) || store.letterboxdBusy)
            if editing {
                Button("Cancel") { editing = false }.buttonStyle(.bordered)
            }
        }
        Label("fusionha can’t verify that a username is yours. It only reads public pages, so a private profile can’t be read at all.",
              systemImage: "info.circle")
            .font(.caption).foregroundStyle(Theme.mut)
    }

    // MARK: Connected

    private func connectedRow(_ user: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(user)").font(.body.weight(.semibold)).foregroundStyle(Theme.txt)
                Text("letterboxd.com/\(user) · public data only").font(.caption).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 8)
            Menu {
                Button("Change username", systemImage: "pencil") { startEditing(user) }
                Button("Disconnect", systemImage: "trash", role: .destructive) { askingDisconnect = true }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 18))
            }
            .accessibilityLabel("Letterboxd profile options")
        }
        .modifier(DisconnectConfirm(user: user, isPresented: $askingDisconnect, disconnect: disconnect))
    }

    // MARK: Can't read

    @ViewBuilder
    private func problemRows(_ user: String) -> some View {
        let problem = LetterboxdLogic.profileProblem(read)
        WatchlistAttention(lead: problem.lead, rest: "\(problem.rest) Checks are paused. Nothing has been requested from it.")
        HStack(spacing: 8) {
            Button("Change username", systemImage: "pencil") { startEditing(user) }
            Button { connect(user) } label: {
                if store.letterboxdBusy {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
                } else {
                    Label("Try again", systemImage: "arrow.clockwise")
                }
            }
            .disabled(store.letterboxdBusy)
        }
        .buttonStyle(.bordered)
        Button("Disconnect", role: .destructive) { askingDisconnect = true }
            .modifier(DisconnectConfirm(user: user, isPresented: $askingDisconnect, disconnect: disconnect))
    }

    // MARK: Actions

    private func startEditing(_ user: String) {
        typing = user
        editing = true
    }

    private func connect(_ name: String) {
        Task {
            guard let next = await store.letterboxdChange(model, { try await $0.updateLetterboxd(username: name) }) else { return }
            if next.profileError != nil {
                model.toast("Couldn’t read that profile", variant: .error)
                return
            }
            editing = false
            model.toast("Profile found. Choose what the diary requests.")
            if next.diary?.enabled != true { diaryChoosing = true }
        }
    }

    private func disconnect() {
        Task {
            await store.sourceChange(model, success: "Letterboxd disconnected · requests already made stay") {
                try await $0.disconnectLetterboxd()
            }
        }
    }
}

/// "Disconnect @user?": requests already made stay, linked lists are untouched.
private struct DisconnectConfirm: ViewModifier {
    let user: String
    @Binding var isPresented: Bool
    let disconnect: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog("Disconnect @\(user)?", isPresented: $isPresented, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive, action: disconnect)
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("fusionha stops reading your diary and watchlist. Requests already made stay, and your linked lists are untouched.")
        }
    }
}
