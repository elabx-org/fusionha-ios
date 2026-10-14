import SwiftUI
import FusionhaKit

extension SignInView {
    // MARK: Actions

    func pick(_ choice: SignInMethod, url: URL) {
        error = nil
        if choice != .plex { cancelPlex() }
        method = choice
        if choice == .plex && plexPin == nil { Task { await startPlex(url: url) } }
    }

    func reset() {
        cancelPlex()
        connected = nil
        method = nil
        error = nil
    }

    func connect() async {
        await run {
            let (url, status) = try await model.connect(server: server)
            withAnimation(.snappy) {
                connected = (url, status)
                method = nil
            }
        }
    }

    func passwordSignIn(url: URL) async {
        // Living logo: let the pins align, glint and spin, then go in; a wrong
        // password jams the pins and the form shakes "no".
        let celebrate = isLiving && !motionOff
        let engine = living
        await run {
            try await model.signIn(server: url, username: username, password: password,
                                   beforeEnter: celebrate ? {
                                       engine.unlock()
                                       try? await Task.sleep(for: .milliseconds(LivingEngine.unlockMs))
                                   } : nil)
        }
        if celebrate, error != nil {
            living.fail()
            nudges += 1
        }
    }

    func startPlex(url: URL) async {
        working = true
        error = nil
        defer { working = false }
        do {
            let pin = try await model.startPlexSignIn(server: url)
            guard let auth = URL(string: pin.authUrl) else { throw APIError.http(status: 502, body: "") }
            plexPin = pin
            plexURL = auth
            plexTask = Task {
                do {
                    try await model.completePlexSignIn(server: url, pin: pin) {
                        // Close the Plex sheet first: once signed in this screen goes
                        // away, and a sheet left on a removed view stays on screen.
                        plexURL = nil
                        try? await Task.sleep(for: .milliseconds(450))
                    }
                } catch is CancellationError {
                } catch APIError.http(403, _) {
                    plexURL = nil
                    error = "Your Plex account doesn't have access to this server."
                    model.toast("Your Plex account doesn't have access to this server.", title: "Access denied", variant: .error)
                } catch PlexSignInError.timedOut {
                    plexURL = nil
                    error = "The authorization window expired. Please try again."
                    model.toast("The authorization window expired. Please try again.", title: "Plex sign-in timed out",
                                variant: .error)
                } catch {
                    plexURL = nil
                    self.error = error.localizedDescription
                    model.toast(error.localizedDescription, title: "Plex sign-in failed", variant: .error)
                }
                plexTask = nil
                plexPin = nil
            }
        } catch {
            self.error = "Could not start Plex sign-in"
            model.toast(error.localizedDescription, title: "Could not start Plex sign-in", variant: .error)
        }
    }

    func cancelPlex() {
        plexTask?.cancel()
        plexTask = nil
        plexPin = nil
        plexURL = nil
    }

    func run(_ work: () async throws -> Void) async {
        working = true
        error = nil
        defer { working = false }
        do {
            try await work()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
