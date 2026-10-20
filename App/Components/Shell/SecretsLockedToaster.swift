import SwiftUI
import Combine
import FusionhaKit

// The web's `SecretsLockedToaster`: every write refused with `409
// secrets_locked` (reported once by `APIClient` on `SecretsLockedBus`) becomes
// one warning toast with "Open Settings → Security". Silent on the Security
// panel itself, which explains the lock in place.

extension AppModel {
    func secretsLocked() {
        let onSecurity = avatar.settingsShown == SecretsLockedBus.securityPanel
        guard avatar.secretsGate.admit(at: .now, onSecurityPanel: onSecurity) else { return }
        let action = requestScoped ? nil : ToastAction(label: SecretsLockedBus.actionLabel) { [weak self] in
            self?.openSettings(panel: SecretsLockedBus.securityPanel)
        }
        toast(SecretsLockedBus.message, title: SecretsLockedBus.title, variant: .warning,
              duration: SecretsLockedBus.duration, action: action)
    }

    /// Opens a Settings panel from anywhere: the open Settings jumps to it,
    /// else full-screen Settings opens on it once a covering sheet has closed.
    func openSettings(panel: String) {
        if avatar.settingsShown != nil {
            avatar.settingsJump = panel
        } else if showingAccount {
            avatar.pending = .settings(panel)
            showingAccount = false
        } else if avatar.showingSheet {
            avatar.pending = .settings(panel)
            avatar.showingSheet = false
        } else {
            avatar.settingsPanel = panel
            avatar.showingSettings = true
        }
    }
}

/// Listens for refused writes once, around the shell, and routes
/// Discover's toasts into the app's stack.
struct SecretsLockedToaster: ViewModifier {
    let model: AppModel

    func body(content: Content) -> some View {
        content
        .onAppear {
            // One toast stack: Discover's toaster reports through the app's.
            DiscoverToasts.shared.sink = { [weak model] variant, message, title in
                let mapped: ToastVariant = switch variant {
                case .success: .success
                case .info: .info
                case .error: .error
                }
                model?.toast(message, title: title, variant: mapped, duration: variant == .error ? 6 : 4)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: SecretsLockedBus.notification).receive(on: RunLoop.main)
        ) { _ in
            model.secretsLocked()
        }
    }
}

/// Settings' side of the link: reports its top panel (for the toaster's
/// silence), follows a toast's jump, and shows the app's toasts over the
/// full-screen cover.
struct SettingsShellLink: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var path: [String]
    /// The panel pane's global frame while Settings is split, else `nil`.
    var pane: CGRect?

    func body(content: Content) -> some View {
        content
            // The trailing side of the fold in Book pose (DC14); flat open and
            // split, the panel pane.
            .overlay { FoldToastLayer(pane: pane) }
            .onChange(of: path, initial: true) { model.avatar.settingsShown = path.last ?? "" }
            .onChange(of: model.avatar.settingsJump) {
                guard let jump = model.avatar.settingsJump else { return }
                model.avatar.settingsJump = nil
                path = [jump]
            }
            .onDisappear { model.avatar.settingsShown = nil }
    }
}
