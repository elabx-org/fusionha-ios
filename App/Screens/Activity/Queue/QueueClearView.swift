import SwiftUI
import FusionhaKit

/// Activity › Queue when nothing is downloading (the web's `QueueIdle`):
/// "Queue clear" with system status instead of a blank list. One cheap
/// read-only call (`GET /activity/idle-summary`), refreshed every 30 seconds.
struct QueueClearView: View {
    @Environment(AppModel.self) private var model
    @State private var summary: IdleSummary?
    @State private var failed = false
    @State private var range: HistoryRange = .today

    enum HistoryRange: String, CaseIterable { case today = "Today", week = "7 days" }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero
            if let summary {
                historyPills(summary)
                readiness(summary)
            } else if failed {
                Text("Readiness is unavailable right now.").font(.system(size: 13)).foregroundStyle(Theme.mut)
            } else {
                Text("Checking clients, indexers and disk…").font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let next = try await client.idleSummary()
            if next != summary { summary = next }
            failed = false
        } catch is CancellationError {
        } catch {
            failed = summary == nil
        }
    }

    // MARK: Pieces

    private var hero: some View {
        let ready = summary?.isReady ?? true
        let tone = ready ? Theme.done : Theme.miss
        return HStack(spacing: 14) {
            Image(systemName: ready ? "checkmark" : "exclamationmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tone)
                .frame(width: 48, height: 48)
                .background(tone.opacity(0.12), in: Circle())
                .overlay(Circle().strokeBorder(tone.opacity(0.45), lineWidth: 2))
                .symbolEffect(.bounce, value: ready)
            VStack(alignment: .leading, spacing: 3) {
                Text("Queue clear").font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.txt)
                Text(summary?.readinessLabel ?? "All systems ready")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(tone)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func historyPills(_ s: IdleSummary) -> some View {
        let counts = range == .today ? s.history.today : s.history.week
        return HStack(spacing: 12) {
            Picker("Range", selection: $range) {
                ForEach(HistoryRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            (Text("\(counts.grabbed)").bold().foregroundColor(Theme.txt) + Text(" grabbed · ")
             + Text("\(counts.imported)").bold().foregroundColor(Theme.txt) + Text(" imported · ")
             + Text("\(counts.failed)").bold().foregroundColor(counts.failed > 0 ? Theme.danger : Theme.txt) + Text(" failed"))
                .font(.system(size: 13)).foregroundStyle(Theme.mut)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func readiness(_ s: IdleSummary) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                tile("Download clients",
                     s.clients.total == 0 ? "none configured" : "\(s.clients.enabled) of \(s.clients.total) on",
                     s.clients.items.map { "\($0.name) · \($0.enabled ? IdleSummary.protocolLabel($0.protocol) : "off")" }
                        .joined(separator: "\n"))
                if let disk = s.disk {
                    tile("Free space", ActFmt.bytes(Double(disk.freeBytes)),
                         "of \(ActFmt.bytes(Double(disk.totalBytes))) · \(disk.roots) root\(disk.roots == 1 ? "" : "s")"
                         + (disk.volumes == 1 ? ", one volume" : ", \(disk.volumes) volumes"))
                } else {
                    tile("Free space", "—", "roots not readable")
                }
                tile("Indexers", "\(s.indexers.healthy) / \(s.indexers.total) healthy",
                     (s.indexers.backoff > 0 ? "\(s.indexers.backoff) in backoff · " : "") + "\(s.history.grabbed24h) grabs 24h")
                if let rss = s.tasks.rss { taskTile("Next RSS sync", rss) }
                if let search = s.tasks.search { taskTile("Next search", search) }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func taskTile(_ title: String, _ task: IdleSummary.Task) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            tile(title,
                 task.running ? "Running…" : ActFmt.countdown(task.nextRun, now: context.date),
                 IdleSummary.everyLabel(seconds: task.intervalSeconds)
                    + (task.lastDuration.map { " · last took \(Int($0.rounded()))s" } ?? ""))
        }
    }

    private func tile(_ title: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dim)
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            Text(sub).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(3)
        }
        .padding(14)
        .frame(width: 168, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .actWash(Color?.none)
    }
}
