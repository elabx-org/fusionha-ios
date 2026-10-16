import SwiftUI
import FusionhaKit

/// "Other addresses (N)", collapsed (web `ConnectionList`): Your network /
/// Custom domains & remote (reachable first) / Docker networks (collapsed
/// again, with why) / Relay ("avoid"). Compact rows: label, kind, dot + ms or
/// "no reply", and Use; a tap on a row shows its full URL.
struct PlexConnectionList: View {
    let conns: [PlexConnection]
    let results: PlexProbeMap
    let recUri: String?
    let savingUri: String?
    let onUse: (String) -> Void
    @State private var open = false
    @State private var docker = false

    private var others: [PlexConnection] { conns.filter { $0.uri != recUri } }

    var body: some View {
        let ok = others.filter { PlexConnectionLabels.isUsable(results[$0.uri]) }.count
        DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(PlexConnectionLabels.otherGroups(conns, results, recUri: recUri)) { entry in
                    groupView(entry.group, entry.list)
                }
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 6) {
                Text("Other addresses").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                PlexChip(text: "\(others.count)")
                Text("\(ok) reachable · \(others.count - ok) not").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        }
        .tint(Theme.mut)
    }

    @ViewBuilder
    private func groupView(_ group: PlexConnectionLabels.Group, _ list: [PlexConnection]) -> some View {
        let head = HStack(spacing: 6) {
            Text(group.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            PlexChip(text: "\(list.count)")
            Text(PlexConnectionLabels.groupSummary(list, results)).font(.system(size: 11.5)).foregroundStyle(Theme.dim)
        }
        VStack(alignment: .leading, spacing: 6) {
            if group.collapsible {
                DisclosureGroup(isExpanded: $docker) {
                    note(group)
                    rows(list)
                } label: { head }
            } else {
                head
                note(group)
                rows(list)
            }
        }
    }

    @ViewBuilder
    private func note(_ group: PlexConnectionLabels.Group) -> some View {
        if let text = group.note {
            Text(text).font(.system(size: 11.5)).foregroundStyle(group.avoid ? Theme.stuck : Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func rows(_ list: [PlexConnection]) -> some View {
        ForEach(list) { c in
            PlexAddressRow(conn: c, result: results[c.uri], saving: savingUri == c.uri,
                           busy: savingUri != nil) { onUse(c.uri) }
        }
    }
}

/// One compact address row; tapping the label reveals the full URL with copy.
private struct PlexAddressRow: View {
    let conn: PlexConnection
    let result: PlexConnectionProbe?
    let saving: Bool
    let busy: Bool
    let onUse: () -> Void
    @State private var expanded = false

    var body: some View {
        let tail = PlexConnectionLabels.probeTail(result)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button { expanded.toggle() } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(conn.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                        Text(PlexConnectionLabels.kindLine(conn)).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(expanded ? "Hides the full address" : "Shows the full address")
                HStack(spacing: 5) {
                    Circle().fill(PlexColors.tail(tail.state)).frame(width: 7, height: 7)
                    Text(tail.text).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(1)
                }
                .accessibilityHint(tail.title ?? "")
                Button(saving ? "Saving…" : "Use", action: onUse)
                    .buttonStyle(.web())
                    .disabled(!PlexConnectionLabels.isUsable(result) || busy)
                    .accessibilityLabel("Use \(conn.label)")
            }
            if expanded {
                HStack(spacing: 6) {
                    MonoText(conn.uri).lineLimit(2)
                    PlexCopyButton(uri: conn.uri)
                }
            }
        }
        .opacity(tail.state == .fail ? 0.7 : 1)
    }
}
