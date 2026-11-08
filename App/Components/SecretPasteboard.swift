import UIKit
import UniformTypeIdentifiers

/// Copies a secret (an API key, a token, a recovery key, a feed URL holding a
/// key): this device only (no Universal Clipboard), and gone after two minutes.
enum SecretPasteboard {
    static let lifetime: TimeInterval = 120

    static func copy(_ secret: String) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: secret]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(lifetime)])
    }
}
