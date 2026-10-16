import SwiftUI
import FusionhaKit

/// "UHD·4K access from Plex" (web `AccessCard`): the derive switch, the access
/// sync, then by state: the live breakdown (active), an inert note
/// (acknowledged, switch off) or the preview to acknowledge.
struct PlexAccessSection: View {
    let plex: PlexServerModel
    @Environment(SettingsStore.self) private var store

    private var active: Bool { plex.preview?.active == true }

    var body: some View {
        SettingsSection("UHD·4K access from Plex") {
            Toggle(isOn: deriveBinding) {
                FieldLabel(label: "Derive UHD·4K access from Plex shares",
                           description: "The Plex owner and Plex Home users always get UHD·4K. Friends get it when you share a 4K library with them.")
            }
            .tint(Theme.indigo)
            .disabled(plex.savingSetting)
            .settingsField("Derive UHD·4K access from Plex shares")
            Text("A UHD·4K grant set by hand on a user always wins. Open requests are never cancelled; a change only affects new requests and auto-approval."
                 + (active ? "" : " Nothing changes until you acknowledge the preview."))
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            PlexSyncRow(plex: plex)
            if let p = plex.preview {
                if p.active {
                    PlexActiveBlock(plex: plex, preview: p)
                    PlexWhoGets4KCard(plex: plex, active: true, synced: p.synced)
                } else if let ack = p.acknowledgedAt, !ack.isEmpty {
                    Text("Acknowledged \(PlexLibraryEvidence.formatAckDate(ack)). Inactive while the switch is off: users without a manual grant are unrestricted.")
                        .font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    PlexWhoGets4KCard(plex: plex, active: false, synced: p.synced)
                    PlexAckBlock(plex: plex, preview: p)
                }
            }
        }
    }

    private var deriveBinding: Binding<Bool> {
        Binding(get: { store.bool("plex_derive_uhd_access", true) }, set: { v in
            Task { await plex.saveSetting("plex_derive_uhd_access", .bool(v), store: store, errorTitle: "Could not change Plex derivation") }
        })
    }
}

/// "Plex access sync" (web `SyncRow`): last complete sync, cadence, overdue,
/// "Sync now" and the outcome. "Scheduled syncs are backing off" describes
/// only the AUTOMATIC sync; a manual run always goes straight through.
struct PlexSyncRow: View {
    let plex: PlexServerModel
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let sum = PlexSyncStatus.summary(lastSyncedAt: plex.preview?.lastSyncedAt,
                                         hours: store.int("plex_access_sync_hours", 24))
        LabeledContent {
            Button(plex.syncPhase == .running ? "Syncing…" : "Sync now") { Task { await plex.syncNow() } }
                .buttonStyle(.web())
                .disabled(plex.syncPhase == .running)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Plex access sync").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                description(sum).font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            .padding(.vertical, 4)
        }
        .settingsField("Plex access sync")
        outcome
    }

    private func description(_ sum: PlexSyncStatus.Summary) -> Text {
        if sum.never { return Text("Never run. Reads your Plex shares from plex.tv · every \(sum.hours) h.") }
        let overdue = sum.overdue ? Text(" · \(Text("overdue").foregroundStyle(Theme.stuck).bold())") : Text("")
        return Text("Last complete sync \(Text(sum.ago).monospaced()) · every \(sum.hours) h\(overdue)")
    }

    @ViewBuilder
    private var outcome: some View {
        switch plex.syncPhase {
        case .running:
            PlexNote(color: Theme.grab, symbol: "arrow.clockwise", text: "Syncing Plex access…", spinning: true)
        case .ok:
            PlexNote(color: Theme.done, symbol: "checkmark.circle", text: "Synced · Plex access is up to date.")
        case .failed:
            PlexNote(color: Theme.stuck, symbol: "exclamationmark.triangle", title: "The sync didn't finish",
                     text: "The last known access stays in force. Check the server connection, then try again.")
        case .idle:
            if let p = plex.preview, PlexSyncStatus.backingOff(p.warnings) {
                PlexNote(color: Theme.stuck, symbol: "clock", title: "Scheduled syncs are backing off",
                         text: "The last 3 or more attempts failed, so the automatic sync waits longer between tries. The last known access stays in force. Sync now always runs straight away.")
            }
        }
    }
}
