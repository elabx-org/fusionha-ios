import Foundation
import FusionhaKit

/// The app's windows, held weakly: one in v1, one or more in v2 (split
/// screen). A tapped notification, and in v2 a widget or Live Activity link,
/// goes to the window used last, never to all of them.
struct SessionWindows {
    private struct Entry { weak var model: AppModel? }
    private var all: [Entry] = []
    private weak var lastActive: AppModel?

    mutating func register(_ model: AppModel) {
        all.removeAll { $0.model == nil }
        all.append(Entry(model: model))
    }

    /// The window became active or key (the one the person is using).
    mutating func becameActive(_ model: AppModel) {
        lastActive = model
    }

    /// The window the person used last (active, or made key), if known.
    var used: AppModel? { lastActive }

    /// The newest window still open.
    var newest: AppModel? { all.last(where: { $0.model != nil })?.model }
}

extension AppSession {
    func register(window: AppModel) {
        windows.register(window)
    }

    func windowBecameActive(_ window: AppModel) {
        windows.becameActive(window)
    }

    /// A `fusionha://` link for the app (a notification tap; in v2 also a
    /// widget or Live Activity link): opened in the window used last while it
    /// is in the foreground, else in `fallback` (the scene the system handed
    /// it to). With neither (a cold launch before any window, or a tap while
    /// the windows are in the background) the session keeps it in
    /// `pendingLink` until a window comes forward (`acquirePolling`).
    func routeLink(_ url: URL, fallback: AppModel? = nil) {
        if let target = windows.used.flatMap({ $0.inForeground ? $0 : nil }) ?? fallback {
            target.receiveDeepLink(url)
        } else {
            pendingLink = url
        }
    }

    // MARK: Native push (APNs)

    /// Registers the APNs token whenever iOS issues one, and opens tapped
    /// notifications: once for the app, not once per window.
    func observePush() {
        NotificationCenter.default.addObserver(forName: .apnsTokenChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.registerPushDevice() }
        }
        NotificationCenter.default.addObserver(forName: .openNotificationLink, object: nil, queue: .main) { [weak self] note in
            guard let url = note.object as? URL else { return }
            Task { @MainActor in self?.routeLink(url) }
        }
    }

    /// `POST /api/v1/notifications/apns/devices` for this install, when signed in
    /// (not as the read-only demo, and never against the screenshot mock).
    func registerPushDevice() async {
        guard let client, credentials?.method != .demoCookie,
              ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SERVER"] == nil else { return }
        if let device = await PushRegistration.register(with: client) {
            UserDefaults.standard.set(device.id, forKey: "apnsDeviceId")
        }
        LiveActivityPushTokens.start(client: client)
    }
}
