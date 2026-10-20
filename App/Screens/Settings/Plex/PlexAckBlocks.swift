import SwiftUI
import FusionhaKit

/// Derivation is live (web `ActiveBlock`): the stamp, the 4K libraries it
/// counts, and "Turn off" behind a confirmation.
struct PlexActiveBlock: View {
    let plex: PlexServerModel
    let preview: PlexAccessPreview
    @State private var asking = false

    var body: some View {
        let libs = preview.uhdLibraries.isEmpty ? "none" : preview.uhdLibraries.joined(separator: ", ")
        PlexStatusLine(color: preview.uhdLibraries.isEmpty ? Theme.stuck : Theme.done,
                       text: "Active since \(PlexLibraryEvidence.formatAckDate(preview.acknowledgedAt)) · 4K libraries: \(libs)") {
            Button("Turn off") { asking = true }
                .buttonStyle(.web())
                .disabled(plex.acking)
        }
        .confirmationDialog("Turn off Plex-derived UHD·4K access?", isPresented: $asking, titleVisibility: .visible) {
            Button("Turn off", role: .destructive) { Task { _ = await plex.acknowledge(false) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everyone without a manual or role grant goes back to unrestricted: they can request every version, UHD·4K included. Open requests aren't touched. Turning it on again shows a fresh preview to acknowledge.")
        }
    }
}

/// Preview-then-confirm before Plex-derived access first takes effect (web
/// `AckBlock`): who would gain / lose UHD·4K, why acknowledging is blocked,
/// and "Acknowledge and turn on".
struct PlexAckBlock: View {
    let plex: PlexServerModel
    let preview: PlexAccessPreview

    var body: some View {
        let p = preview
        let block = PlexSyncStatus.ackBlock(p)
        VStack(alignment: .leading, spacing: 10) {
            Text("\(Text("\(p.gain.count) gain · \(p.lose.count) lose").bold()) UHD·4K requests if you turn this on now \(Text("(\(p.unchanged) unchanged)").foregroundStyle(Theme.mut)).")
                .font(.system(size: 13)).foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
            names("Would lose UHD·4K", p.lose, empty: "Nobody", uhd: false)
            names("Would gain UHD·4K", p.gain, empty: "Nobody: without Plex derivation everyone is already unrestricted", uhd: true)
            Text("Open requests are never cancelled. A change only affects new requests and auto-approval.")
                .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            if block == .sync {
                blocked(title: "Run a complete access sync first.",
                        text: "Until one has finished, owner and Home users would count as HD.", code: "409 access_not_synced")
            } else if block == .noLibrary {
                blocked(title: "No library is detected as 4K.",
                        text: "Confirm a suggestion or set a library to 4K above.", code: "409 no_uhd_library")
            }
            actions(block)
        }
        .padding(12)
        .background(Theme.stuck.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private func names(_ title: String, _ people: [PlexPreviewUser], empty: String, uhd: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
            if people.isEmpty {
                Text(empty).font(.system(size: 12)).foregroundStyle(Theme.dim)
            } else {
                Text(people.map(\.displayName).joined(separator: ", "))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(uhd ? QualityTier.uhd.color : Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func blocked(title: String, text: String, code: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.stuck)
            Text("\(Text(title).bold()) \(text) \(Text(code).monospaced().foregroundStyle(Theme.dim))")
                .font(.system(size: 12)).foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actions(_ block: PlexSyncStatus.AckBlock?) -> some View {
        HStack(spacing: 8) {
            Button("Acknowledge and turn on") { Task { _ = await plex.acknowledge(true) } }
                .buttonStyle(.web(.primary))
                .disabled(block != nil || !preview.deriveEnabled || plex.acking)
            if block == .sync {
                Button(plex.syncPhase == .running ? "Syncing…" : "Sync now") { Task { await plex.syncNow() } }
                    .buttonStyle(.web())
                    .disabled(plex.syncPhase == .running)
            }
            if !preview.deriveEnabled {
                Text("Turn the switch on first.").font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
        }
    }
}

/// The "who gets UHD·4K" breakdown (web `WhoGets4K`): one washed card per
/// non-empty group, each name tinted UHD or HD.
struct PlexWhoGets4KCard: View {
    let plex: PlexServerModel
    let active: Bool
    let synced: Bool

    var body: some View {
        let buckets = PlexWhoGets4K.group(plex.tierAccess, names: plex.names, synced: synced)
        if !buckets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(active ? "Who gets UHD·4K now" : "Who would get UHD·4K")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
                // Web `.buckets`: auto-fill minmax(210, 1fr), 8 apart.
                AutoFillGrid(minItemWidth: 210, spacing: 8) {
                    ForEach(buckets) { b in card(b) }
                }
            }
        }
    }

    private func card(_ b: PlexBucket) -> some View {
        let color = PlexColors.bucket(b.id.tone)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("\(b.people.count)").font(.system(size: 18, weight: .bold).monospacedDigit()).foregroundStyle(color)
                Text(b.id.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            if !b.sub.isEmpty { Text(b.sub).font(.system(size: 11.5)).foregroundStyle(Theme.mut) }
            names(b.people)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Each name tinted UHD·4K (cyan) or HD only (purple).
    private func names(_ people: [PlexBucket.Person]) -> Text {
        var text = Text("")
        for (i, person) in people.enumerated() {
            let name = Text(person.name).foregroundStyle(person.uhd ? QualityTier.uhd.color : QualityTier.hd.color)
            text = i == 0 ? name : Text("\(text), \(name)")
        }
        return text
    }
}
