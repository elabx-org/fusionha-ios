import SwiftUI
import FusionhaKit

/// "Not encrypted" beside a server reached over plain http that isn't on this
/// network (`ServerAddress.isUnencrypted`): quiet, in the line's own colour.
/// Shows nothing for https or a home-network address.
struct UnencryptedMark: View {
    let server: URL?
    var size: CGFloat = 12

    var body: some View {
        if let server, ServerAddress.isUnencrypted(server) {
            Label("Not encrypted", systemImage: "lock.open")
                .labelStyle(.titleAndIcon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .fixedSize()
                .accessibilityLabel("Not encrypted: this server uses plain http")
        }
    }
}
