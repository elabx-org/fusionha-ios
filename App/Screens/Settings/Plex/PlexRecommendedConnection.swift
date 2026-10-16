import SwiftUI
import FusionhaKit

/// The one Recommended card on a green wash (web `RecommendedConnection`):
/// label · kind · ms · "your server", why, the full URL with copy, and "Use this".
struct PlexRecommendedConnection: View {
    let rec: PlexConnectionProbe
    let saved: String
    let saving: Bool
    let onUse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Recommended", systemImage: "checkmark.circle")
                .font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.done)
            Text(rec.label).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
            HStack(spacing: 10) {
                Text(PlexConnectionLabels.kindText(rec.kind))
                Text("\(rec.latencyMs ?? 0) ms").monospacedDigit()
                Label("your server", systemImage: "checkmark.circle").foregroundStyle(Theme.done)
            }
            .font(.system(size: 12)).foregroundStyle(Theme.mut)
            Text(PlexConnectionLabels.recReason(rec.kind))
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                MonoText(rec.uri).lineLimit(1).truncationMode(.middle)
                PlexCopyButton(uri: rec.uri)
            }
            if rec.plexDirect {
                Text("Secure plex.direct address — this is what gets saved.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
            }
            Button(saving ? "Saving…" : rec.uri == saved ? "Keep using this" : "Use this", action: onUse)
                .buttonStyle(.web(.primary))
                .disabled(saving)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.done.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}
