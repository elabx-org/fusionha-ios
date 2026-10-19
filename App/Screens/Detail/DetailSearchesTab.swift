import SwiftUI
import FusionhaKit

// MARK: - Searches

struct SearchesTab: View {
    @Environment(DetailStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.runsLoaded {
                DetailSpinner(size: 20, color: Theme.mut).frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if store.runs.isEmpty {
                Text("No searches yet for this title. Manual searches, RSS syncs and scheduled sweeps that touch it show up here — each with what it grabbed and why.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .padding(.horizontal, 20)
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            } else {
                ForEach(store.runs) { run in
                    RunRow(run: run)
                }
            }
        }
    }
}

private struct RunRow: View {
    let run: CommandRun

    private var statusColor: Color {
        switch run.status ?? "" {
        case "running": return Theme.grab
        case "failed": return Theme.danger
        case "interrupted": return Theme.stuck
        default: return (run.grabbed ?? 0) + (run.upgraded ?? 0) > 0 ? Theme.done : Theme.mut
        }
    }

    private var statusToken: MonoToken? {
        switch run.status ?? "" {
        case "running": return .grab
        case "failed": return .danger
        case "interrupted": return .stuck
        default: return (run.grabbed ?? 0) + (run.upgraded ?? 0) > 0 ? .done : nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if run.isRunning { DetailSpinner(size: 12, color: Theme.grab) } else { DetailDot(color: statusColor, size: 9, mono: statusToken) }
            }
            .frame(width: 14, height: 18)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(run.targetSummary ?? run.targetTitle ?? run.name ?? "Search")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(2)
                    if let trigger = triggerLabel(run.trigger) {
                        Text(trigger)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                }
                Text(counts).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.mut)
                if let detail = run.detail, !detail.isEmpty {
                    Text(detail).font(.system(size: 11.5).italic()).foregroundStyle(Theme.dim)
                }
            }
            Spacer(minLength: 0)
            Text(DetailText.relative(run.startedAt)).font(.system(size: 11.5)).foregroundStyle(Theme.dim).fixedSize()
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
    }

    private var counts: String {
        var parts = ["\(run.releases ?? 0) releases"]
        let grabbed = (run.grabbed ?? 0) + (run.upgraded ?? 0)
        if grabbed > 0 { parts.append("\(grabbed) grabbed") }
        if let r = run.rejected, r > 0 { parts.append("\(r) rejected") }
        if let e = run.errors, e > 0 { parts.append("\(e) errors") }
        return parts.joined(separator: " · ")
    }
}
