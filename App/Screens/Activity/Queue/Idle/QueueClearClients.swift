import SwiftUI
import FusionhaKit

/// The phone strip's "2 clients ›" disclosure (web `QueueClearStrip`): on a
/// phone the Download clients tile leaves the grid, so the list folds in here.
struct QueueClearClientsToggle: View {
    let clients: IdleSummary.Clients
    let label: String
    let allOn: Bool
    @Binding var open: Bool
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let tone = allOn ? Theme.done : Theme.miss
        Button {
            if reduce { open.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } }
        } label: {
            HStack(spacing: 6) {
                IdleClientDot(on: allOn)
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.mut)
                    .rotationEffect(.degrees(open ? 90 : 0))
            }
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(Capsule().fill(Theme.panel2).overlay(Capsule().fill(tone.opacity(0.10))))
            .overlay(Capsule().strokeBorder(tone.opacity(0.3)))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(open ? "expanded" : "collapsed")")
    }
}

/// The client list: a dot, the name and its protocol (or "off").
struct QueueClearClientList: View {
    let clients: [IdleSummary.Client]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(clients) { client in
                HStack(spacing: 7) {
                    IdleClientDot(on: client.enabled)
                    Text(client.name)
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 6)
                    Text(client.enabled ? IdleSummary.protocolLabel(client.protocol) : "off")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                        .lineLimit(1).fixedSize()
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A 7 pt status dot with a soft halo: green on, amber off.
struct IdleClientDot: View {
    let on: Bool

    var body: some View {
        let tone = on ? Theme.done : Theme.miss
        Circle().fill(tone).frame(width: 7, height: 7)
            .background(Circle().fill(tone.opacity(0.2)).frame(width: 13, height: 13))
            .frame(width: 13, height: 13)
            .accessibilityHidden(true)
    }
}
