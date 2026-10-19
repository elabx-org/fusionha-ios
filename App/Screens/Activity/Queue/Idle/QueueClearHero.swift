import SwiftUI
import FusionhaKit

/// "Queue clear" (web `QueueClearHero`): the full hero when there is room
/// (icon, title + ready badge, the sub line, the quip, the range pills on the
/// right) and, at phone width, the compact strip (icon, title, quip, then the
/// clients disclosure, Today | 7 days and the pills). The readiness tiles sit
/// inside the same card. The card carries a solid wash: green ready, amber
/// needs a look.
struct QueueClearHero: View {
    let summary: IdleSummary?
    let failed: Bool
    let episodes48h: Int?
    let celebrate: Bool
    let playful: Bool
    let quipSeed: String
    let compact: Bool
    let tileColumns: Int
    let openHistory: () -> Void
    @State private var range: IdleRange = .today
    @State private var clientsOpen = false

    var body: some View {
        let ready = summary?.isReady ?? true
        VStack(alignment: .leading, spacing: compact ? 12 : 18) {
            if compact { strip(ready: ready) } else { head(ready: ready) }
            ReadinessTiles(summary: summary, columns: tileColumns, compact: compact)
        }
        .padding(compact ? EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
                         : EdgeInsets(top: 20, leading: 22, bottom: 18, trailing: 22))
        .frame(maxWidth: .infinity, alignment: .leading)
        .idleCard(tint: ready ? Theme.done : Theme.miss, base: Theme.panel)
    }

    // MARK: Wide

    private func head(ready: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            QueueClearIcon(ready: ready, size: 48, celebrate: celebrate)
            VStack(alignment: .leading, spacing: 5) {
                QueueClearTitle(summary: summary, size: 19)
                QueueClearSubLine(summary: summary, failed: failed, episodes: episodes48h)
                if playful { QueueClearQuip(seed: quipSeed).padding(.top, 1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 8) {
                IdleRangePicker(range: $range)
                IdlePillRow(history: summary?.history, range: range, openHistory: openHistory)
            }
            .fixedSize()
        }
    }

    // MARK: Phone strip

    private func strip(ready: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                QueueClearIcon(ready: ready, size: 32, celebrate: celebrate)
                VStack(alignment: .leading, spacing: 1) {
                    QueueClearTitle(summary: summary, size: 16)
                    if summary == nil {
                        Text(failed ? "Readiness is unavailable right now." : "Checking clients, indexers and disk…")
                            .font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(1)
                    } else if playful {
                        QueueClearQuip(seed: quipSeed, compact: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ActFlow(spacing: 6, lineSpacing: 0) {
                if let summary {
                    QueueClearClientsToggle(clients: summary.clients, label: summary.clientsToggleLabel,
                                            allOn: summary.allClientsOn, open: $clientsOpen)
                }
                IdleRangePicker(range: $range).frame(minHeight: 44)
                IdlePillRow(history: summary?.history, range: range, compact: true, openHistory: openHistory)
            }
            if clientsOpen, let summary {
                QueueClearClientList(clients: summary.clients.items)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.panel2)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.done.opacity(0.07))))
                    .transition(.opacity)
            }
        }
    }
}
