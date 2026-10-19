import SwiftUI
import FusionhaKit

/// "Plex account" (web `PlexLinkSection`): link a Plex identity onto this
/// account (it keeps its password and role), or unlink it. Mints a PIN, opens
/// Plex, and polls every 2s for up to 10 minutes.
struct SignInPlexLinkCard: View {
    let subject: SignInSubject
    @Binding var toast: CalToast?
    let onChanged: () async -> Void
    @Environment(AppModel.self) private var model
    @State private var starting = false
    @State private var waiting = false
    @State private var authURL: URL?
    @State private var task: Task<Void, Never>?
    @State private var unlinking = false

    var body: some View {
        HStack(spacing: 12) {
            SignInProviderTile(provider: "plex", size: 46, radius: 12)
            VStack(alignment: .leading, spacing: 3) { status }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .sheet(item: $authURL) { url in SafariView(url: url).ignoresSafeArea() }
        .onDisappear { task?.cancel() }
        action
    }

    @ViewBuilder
    private var status: some View {
        if subject.plexLinked {
            HStack(spacing: 6) {
                Text(subject.plexUsername ?? "Plex").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                SignInPill(word: "Linked")
            }
            Text("Can sign in with Plex; password still works.").font(.system(size: 12)).foregroundStyle(Theme.mut)
        } else if waiting {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Waiting for Plex authorization…").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
        } else {
            Text("Not linked").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
            Text("No Plex account is linked to this fusionha account.").font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
    }

    @ViewBuilder
    private var action: some View {
        if subject.plexLinked {
            Button(unlinking ? "Unlinking…" : "Unlink") { Task { await unlink() } }
                .buttonStyle(CalButtonStyle(variant: .danger))
                .disabled(unlinking)
        } else if waiting {
            Button("Cancel") { cancel() }
                .buttonStyle(CalButtonStyle(variant: .ghost))
        } else {
            Button(starting ? "Starting…" : "Link Plex account") { start() }
                .buttonStyle(CalButtonStyle(variant: .subtle))
                .disabled(starting)
        }
    }

    private func unlink() async {
        guard let client = model.client else { return }
        unlinking = true
        defer { unlinking = false }
        do {
            try await client.unlinkPlex(userId: subject.id)
        } catch {
            toast = CalToast(title: "Could not unlink Plex",
                             message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
        }
        await onChanged()
    }

    /// `POST …/plex/link`, open Plex, then poll `…/check` every 2s for up to 10 minutes.
    private func start() {
        guard let client = model.client else { return }
        starting = true
        task?.cancel()
        task = Task {
            do {
                let pin = try await client.startPlexLink(userId: subject.id)
                starting = false
                waiting = true
                authURL = URL(string: pin.authUrl)
                let deadline = Date().addingTimeInterval(600)
                while !Task.isCancelled {
                    if Date() > deadline {
                        finish()
                        toast = CalToast(title: "Plex link timed out",
                                         message: "The authorization window expired. Please try again.", isError: true)
                        return
                    }
                    try await Task.sleep(for: .seconds(2))
                    if case .linked(let updated) = try await client.checkPlexLink(userId: subject.id, pinId: pin.id) {
                        finish()
                        toast = CalToast(title: "Plex account linked",
                                         message: "Signed in with Plex as \(updated.plexUsername ?? "Plex") — the password still works.")
                        await onChanged()
                        return
                    }
                }
            } catch is CancellationError {
            } catch APIError.http(409, _) {
                finish()
                toast = CalToast(title: "Already linked",
                                 message: "That Plex account is already linked to another user.", isError: true)
            } catch {
                finish()
                toast = CalToast(title: "Could not link Plex",
                                 message: (error as? APIError)?.serverMessage ?? error.localizedDescription, isError: true)
            }
        }
    }

    private func finish() {
        starting = false
        waiting = false
        authURL = nil
    }

    private func cancel() {
        task?.cancel()
        task = nil
        finish()
    }
}
