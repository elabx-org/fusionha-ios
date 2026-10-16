import SwiftUI
import FusionhaKit

/// The connection status under "Test connection" (web `ServerStatus`):
/// testing → this session's test → the last stored probe → not tested / not connected.
struct PlexServerStatusRow: View {
    let saved: String
    let testing: Bool
    let result: PlexServerTestResult?
    let server: PlexServerInfo?

    var body: some View {
        content.accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        if testing {
            PlexStatusLine(color: Theme.grab, text: "Testing \(saved)…", live: true)
        } else if let probe {
            PlexStatusLine(color: probe.ok ? Theme.done : Theme.danger,
                           text: probe.message + (probe.ok && !(probe.version ?? "").isEmpty ? " · Plex \(probe.version ?? "")" : ""),
                           meta: meta(probe))
        } else {
            PlexStatusLine(color: Theme.dim, text: saved.isEmpty ? "Not connected" : "Not tested yet",
                           meta: saved.isEmpty ? "use the recommended address above" : "Test connection checks the saved URL")
        }
    }

    private struct Probe {
        let ok: Bool
        let message: String
        let version: String?
        let machineId: String?
        let checked: String
    }

    private var probe: Probe? {
        if let result {
            return Probe(ok: result.ok, message: result.message, version: result.version,
                         machineId: result.machineId, checked: "checked just now")
        }
        guard let s = server, s.ok != nil, let message = s.message, !message.isEmpty else { return nil }
        let checked = s.checkedAt.map { "checked \(PlexSyncStatus.shortAgo($0))" } ?? ""
        return Probe(ok: s.ok == true, message: message, version: s.version, machineId: s.machineId, checked: checked)
    }

    private func meta(_ p: Probe) -> String {
        var parts: [String] = []
        if p.ok, let id = p.machineId, !id.isEmpty { parts.append("machine \(PlexLibraryEvidence.shortMachineId(id))") }
        if !p.checked.isEmpty { parts.append(p.checked) }
        return parts.joined(separator: " · ")
    }
}

/// The collapsed saved URL (web `UrlSummary`): "Using 10.0.0.9 · your network ·
/// 4 ms" (or "· entered manually") with Copy and Change.
struct PlexURLSummary: View {
    let saved: String
    let conns: [PlexConnection]
    let results: PlexProbeMap
    let onChange: () -> Void

    var body: some View {
        let sum = PlexConnectionLabels.savedSummary(saved, conns, results)
        PlexStatusLine(color: Theme.done, text: "Using \(sum.host)", meta: sum.meta) {
            HStack(spacing: 4) {
                PlexCopyButton(uri: saved, label: "Copy saved address")
                Button("Change", action: onChange).buttonStyle(.web(.ghost))
            }
        }
    }
}
