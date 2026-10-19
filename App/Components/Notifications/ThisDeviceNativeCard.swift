import Combine
import SwiftUI
import UIKit
import FusionhaKit

/// The single "This device" card body (web `ThisDevice.tsx`) for this
/// install's native push: name, state pill, guidance note and the one action
/// the state allows. The caller wraps it in its card and owns the toasts.
struct ThisDeviceNativeCard: View {
    @Environment(AppModel.self) private var model
    let push: NativePushState
    var isAdmin = false
    /// Admins only: opens the APNs key editor.
    var onSetUpApns: (() -> Void)?
    /// A toast for the outcome of Send test / Register.
    let notify: (_ message: String, _ ok: Bool) -> Void

    var body: some View {
        let state = push.state
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "iphone").font(.system(size: 18)).foregroundStyle(Theme.mut)
                .frame(width: 36, height: 36)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(UIDevice.current.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                Text(meta(state)).font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            pill(state)
        }
        .padding(.vertical, 8)
        if let note = note(state) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: note.warn ? "exclamationmark.triangle" : "info.circle")
                    .foregroundStyle(note.warn ? Theme.miss : Theme.i2)
                Text(note.text)
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((note.warn ? Theme.miss : Theme.i2).opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        actions(state)
            .onReceive(NotificationCenter.default.publisher(for: .apnsTokenChanged)) { _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(600)) // let AppModel register first
                    await push.load(model.client)
                }
            }
    }

    private func actions(_ state: NativePushStatus) -> some View {
        HStack(spacing: 10) {
            switch state {
            case .notAsked:
                Button { Task { await push.enable() } } label: { Label("Enable notifications", systemImage: "bell.badge") }
                    .buttonStyle(.web(.primary))
            case .denied:
                Button { NativePushState.openSystemSettings() } label: { Label("Open iOS Settings", systemImage: "gear") }
                    .buttonStyle(.web(.primary))
            case .serverNotConfigured:
                if isAdmin, let onSetUpApns {
                    Button(action: onSetUpApns) { Label("Set up APNs", systemImage: "key") }
                        .buttonStyle(.web(.primary))
                }
            case .registering:
                Button { register() } label: { Label("Register this device", systemImage: "arrow.clockwise") }
                    .buttonStyle(.web(.primary))
                    .disabled(push.registering)
            case .enabled:
                Button { test() } label: { Label("Send test", systemImage: "bolt.fill") }
                    .buttonStyle(.web(.primary))
                    .disabled(push.testing)
                Button("Disable") { disable() }
                    .buttonStyle(.web(.ghost))
                    .disabled(push.disabling)
            case .disabledHere:
                Button { register() } label: { Label("Enable on this device", systemImage: "bell.badge") }
                    .buttonStyle(.web(.primary))
                    .disabled(push.registering)
            case .loading, .serverOff, .noEntitlement:
                EmptyView()
            }
            if push.testing || push.registering {
                ProgressView().controlSize(.mini)
                Text(push.testing ? "Sending…" : "Registering…").font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else if let result = push.testResult {
                Label(result.message, systemImage: result.ok ? "checkmark" : "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(result.ok ? Theme.done : Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    private func test() {
        Task {
            if let outcome = await push.runTest(model.client) { notify(outcome.message, outcome.ok) }
        }
    }

    private func disable() {
        Task {
            let ok = await push.disable(model.client)
            notify(ok ? "Notifications turned off on this device" : "Couldn't turn off notifications here. Try again.", ok)
        }
    }

    private func register() {
        Task {
            let ok = await push.register(model.client)
            if !ok { notify("Couldn't register this device", false) }
        }
    }

    private func meta(_ state: NativePushStatus) -> String {
        if case .disabledHere = state { return "Not enabled here" }
        guard case .enabled(let d) = state else { return "This app" }
        return "This app · \(d.environment) · active \(FetchFormat.ago(d.lastSuccessAt ?? d.lastSeenAt ?? d.createdAt))"
    }

    @ViewBuilder
    private func pill(_ state: NativePushStatus) -> some View {
        switch state {
        case .loading: ProgressView().controlSize(.mini)
        case .enabled(let d):
            if let error = d.lastError, (d.failureCount ?? 0) > 0 {
                FetchPill(text: "● Not delivering", tone: .warn).accessibilityHint(error)
            } else {
                FetchPill(text: "● Enabled", tone: .ok)
            }
        case .serverNotConfigured: FetchPill(text: "● Server not set up", tone: .warn)
        case .serverOff: FetchPill(text: "● Off on server", tone: .off)
        case .denied: FetchPill(text: "● Blocked", tone: .err)
        case .notAsked: FetchPill(text: "● Off", tone: .off)
        case .noEntitlement: FetchPill(text: "● Unavailable", tone: .err)
        case .registering: FetchPill(text: "● Not registered", tone: .off)
        case .disabledHere: FetchPill(text: "● Off", tone: .off)
        }
    }

    private func note(_ state: NativePushStatus) -> (text: String, warn: Bool)? {
        switch state {
        case .serverNotConfigured(let message):
            return (message + (isAdmin
                ? " Add the APNs auth key (.p8), Key ID and Team ID from your Apple Developer account."
                : " Ask an admin to add the APNs key in Settings → Notifications."), true)
        case .serverOff(let message): return (message, true)
        case .denied:
            return ("Notifications for fusionha are turned off in iOS Settings. Turn them on there to get pushes on this device.", true)
        case .notAsked:
            return ("Get grabs, imports, failures and requests as native notifications on this device. Your event choices below apply to every device.", false)
        case .noEntitlement(let error):
            return ("iOS didn't issue a push token (\(error)). The build must be signed with a profile that has Push Notifications enabled for org.elabx.fusionha.", true)
        case .enabled(let d):
            if let error = d.lastError, (d.failureCount ?? 0) > 0 { return ("Last delivery failed: \(error)", true) }
            return nil
        case .loading, .registering, .disabledHere: return nil
        }
    }
}
