import UserNotifications

/// Attaches the poster/backdrop to a push, using the same payload keys the server's
/// Web Push already sends (`image`, falling back to `icon`).
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        bestAttempt = content

        let info = request.content.userInfo
        guard let raw = (info["image"] as? String) ?? (info["icon"] as? String),
              let url = URL(string: raw) else {
            contentHandler(content)
            return
        }

        URLSession.shared.downloadTask(with: url) { location, response, _ in
            defer { contentHandler(content) }
            guard let location else { return }
            let ext = response?.suggestedFilename.flatMap { URL(fileURLWithPath: $0).pathExtension } ?? "jpg"
            let target = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext.isEmpty ? "jpg" : ext)
            do {
                try FileManager.default.moveItem(at: location, to: target)
                let attachment = try UNNotificationAttachment(identifier: "poster", url: target)
                content.attachments = [attachment]
            } catch {}
        }.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttempt { contentHandler(bestAttempt) }
    }
}
