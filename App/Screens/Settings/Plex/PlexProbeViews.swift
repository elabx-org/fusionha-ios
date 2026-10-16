import SwiftUI
import FusionhaKit

/// "Testing 21 addresses…" (web `ProbeProgress`). The probe is ONE request, so
/// there is no honest n/N: an indeterminate bar runs while it is in flight,
/// and one dot per address, grouped like the results, fills in as the answers
/// are revealed.
struct PlexProbeProgress: View {
    let conns: [PlexConnection]
    let results: PlexProbeMap

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.grab)
                Text("Testing \(conns.count) addresses…").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            Text("Plex reported \(conns.count) ways to reach your server. fusionha tries each one from its own network, so the address it recommends is one it can really use.")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(PlexConnectionLabels.groups) { g in
                let list = conns.filter { g.kinds.contains($0.kind) }
                if !list.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(g.title) · \(list.count)").font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                        HStack(spacing: 4) {
                            ForEach(list) { c in
                                Circle().fill(dotColor(results[c.uri])).frame(width: 7, height: 7)
                            }
                        }
                    }
                }
            }
        }
        .padding(11)
        .background(Theme.grab.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private func dotColor(_ r: PlexConnectionProbe?) -> Color {
        guard let r else { return Theme.dim.opacity(0.5) }
        return PlexConnectionLabels.isUsable(r) ? Theme.done : Theme.danger
    }
}

/// The tested state (web `ProbeResults`): the tally, ONE recommendation (or
/// the nothing-answered note), the collapsed others and "Enter manually".
struct PlexProbeResults: View {
    let plex: PlexServerModel
    let saved: String
    let savingUri: String?
    let onUse: (String) -> Void
    let onManual: () -> Void
    let onCancel: (() -> Void)?

    private var list: [PlexConnectionProbe] { plex.probe?.results ?? [] }
    private var rec: PlexConnectionProbe? {
        list.first { $0.uri == plex.probe?.recommendedUri && PlexConnectionLabels.isUsable($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = plex.probeError {
                PlexProbeErrorNote(error: error) { Task { await plex.runProbe() } }
            } else {
                tally
            }
            if let rec {
                PlexRecommendedConnection(rec: rec, saved: saved, saving: savingUri == rec.uri) { onUse(rec.uri) }
            } else if plex.probeError == nil {
                PlexNote(color: Theme.danger, symbol: "exclamationmark.triangle",
                         title: "fusionha couldn't reach any address Plex reported",
                         text: "Check that fusionha and Plex share a network, or enter an address manually.")
            }
            if !list.isEmpty {
                PlexConnectionList(conns: list.map(\.connection), results: plex.probeResults,
                                   recUri: rec?.uri, savingUri: savingUri, onUse: onUse)
            }
            HStack(spacing: 6) {
                Text("Not listed?").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                Button("Enter manually", action: onManual).buttonStyle(.web(.ghost))
                if let onCancel { Button("Cancel", action: onCancel).buttonStyle(.web(.ghost)) }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 2)
    }

    private var tally: some View {
        let ok = list.filter { PlexConnectionLabels.isUsable($0) }.count
        let ago = plex.probe?.checkedAt.map { " · " + PlexSyncStatus.shortAgo($0) } ?? ""
        return VStack(alignment: .leading, spacing: 2) {
            Text("Tested \(Text("\(list.count) addresses").bold()) from fusionha")
                .font(.system(size: 13)).foregroundStyle(Theme.txt)
            Text("\(ok) reachable · \(list.count - ok) unreachable\(ago)")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A failed probe: plex.tv couldn't be asked (coded 503), or anything else.
private struct PlexProbeErrorNote: View {
    let error: Error
    let onRetest: () -> Void

    var body: some View {
        if (error as? APIError)?.code == PlexErrorCode.plexTvUnavailable {
            VStack(alignment: .leading, spacing: 8) {
                PlexNote(color: Theme.stuck, symbol: "exclamationmark.triangle",
                         title: "Couldn't ask Plex for its addresses — try again",
                         text: "plex.tv didn't answer. Your server may be fine.")
                Button("Test again", action: onRetest).buttonStyle(.web())
            }
        } else {
            PlexNote(color: Theme.danger, symbol: "exclamationmark.triangle",
                     title: "Couldn't test the addresses Plex reported",
                     text: "\(error.settingsMessage) Try again, or enter an address manually.")
        }
    }
}
