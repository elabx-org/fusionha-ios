import SwiftUI
import Observation
import FusionhaKit

/// What the avatar opens: the account hub sheet, then (once it has closed)
/// full-screen Settings, the Account sheet or Widget diagnostics. Held by
/// `AppModel` and presented once from the shell (`AvatarPresentations`), so the
/// avatar button only sets a flag and can live anywhere, including a system
/// toolbar or its overflow menu.
@MainActor
@Observable
final class AvatarPresentation {
    var showingSheet = false
    /// Where the hub sends you once it has closed.
    var pending: AccountHubSheet.Destination?
    var showingSettings = SettingsScreenshot.openAtLaunch
    var settingsPanel = SettingsScreenshot.panel
    var showingWidgets = WidgetDiagnosticsView.openAtLaunch
    /// The panel on top of an open Settings (any presenter), nil when closed.
    var settingsShown: String?
    /// A panel for the open Settings to jump to (a toast's action).
    var settingsJump: String?
    /// One secrets-locked toast per burst (`SecretsLockedBus.Gate`).
    var secretsGate = SecretsLockedBus.Gate()
    /// Keychain + App Group probes for the hub's diagnostics, read off the main thread.
    var diagnostics = ""

    /// A deep link closes these so its sheet can show (DeepLink.swift).
    var isOpen: Bool { showingSheet || showingSettings || showingWidgets }

    func closeAll() {
        pending = nil
        showingSheet = false
        showingSettings = false
        showingWidgets = false
    }

    /// The hub's `onDismiss`: open what it picked.
    func openPending(_ model: AppModel) {
        guard let destination = pending else { return }
        pending = nil
        switch destination {
        case .settings(let panel):
            settingsPanel = panel
            showingSettings = true
        case .account:
            model.showingAccount = true
        case .widgets:
            showingWidgets = true
        }
    }
}

/// The avatar's sheets and cover, applied once around the shell.
struct AvatarPresentations: ViewModifier {
    @Bindable var avatar: AvatarPresentation
    let model: AppModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $avatar.showingSheet, onDismiss: { avatar.openPending(model) }) {
                AccountHubSheet(diagnostics: avatar.diagnostics) { avatar.pending = $0 }
                    .presentationDetents([.mediumFitting, .large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $avatar.showingSettings) {
                SettingsView(client: model.client, initialPanel: avatar.settingsPanel)
            }
            .sheet(isPresented: $avatar.showingWidgets) {
                WidgetDiagnosticsView()
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
            .onChange(of: model.linkCloseTick) { avatar.closeAll() }
            .task(id: model.credentials?.serverURL) {
                avatar.diagnostics = await Task.detached(priority: .utility) { CredentialStore.diagnostics() }.value
            }
    }
}
