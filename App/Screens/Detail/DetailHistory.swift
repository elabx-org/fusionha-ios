import SwiftUI
import FusionhaKit

// The History tab (Timeline / Lifecycle / Insights) and the Searches tab.

private enum HistoryMode: String, CaseIterable {
    case timeline, lifecycle, insights
    var title: String { rawValue.capitalized }
}

private func eventStyle(_ type: String) -> (label: String, color: Color) {
    switch type {
    case "GRABBED": return ("Grabbed", Theme.grab)
    case "IMPORTED": return ("Imported", Theme.done)
    case "GRAB_FAILED": return ("Grab failed", Theme.stuck)
    case "NEEDS_ATTENTION": return ("Needs attention", Theme.stuck)
    case "DOWNLOAD_FAILED": return ("Download failed", Theme.danger)
    case "FILE_MOVE_FAILED": return ("Move failed", Theme.danger)
    case "DELETED": return ("Deleted", Theme.danger)
    case "RENAMED": return ("Renamed", Theme.edition)
    case "FILE_MOVED": return ("Moved", Theme.edition)
    case "RENUMBERED": return ("Numbering fixed", Theme.edition)
    case "MOVED_TO_EDITION", "EDITION_MOVED": return ("Moved to edition", Theme.edition)
    default: return (type.replacingOccurrences(of: "_", with: " ").capitalized, Theme.mut)
    }
}

private func triggerLabel(_ trigger: String?) -> String? {
    guard let trigger, !trigger.isEmpty else { return nil }
    switch trigger {
    case "rss": return "RSS"
    case "search": return "Search"
    case "upgrade": return "Upgrade"
    case "interactive": return "Interactive"
    case "forced": return "Forced"
    case "requested": return "Requested"
    case "regrab": return "Re-grabbed"
    case "scheduled": return "Scheduled"
    case "search_on_add": return "Search on add"
    case "manual": return "Manual"
    case "auto_research": return "Auto re-search"
    default: return trigger.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private func triggerIcon(_ trigger: String?) -> String {
    switch trigger ?? "" {
    case "rss": return "dot.radiowaves.up.forward"
    case "upgrade": return "arrow.up"
    case "interactive": return "person"
    case "forced": return "bolt"
    case "requested": return "tray"
    case "regrab": return "arrow.triangle.2.circlepath"
    default: return "magnifyingglass"
    }
}

struct HistoryTab: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    @AppStorage("fusionha:history-view") private var viewRaw = HistoryMode.timeline.rawValue

    private var entries: [HistoryEntry] {
        let ids = store.detail?.scopeEditionIds(store.scope)
        return (detail.history ?? [])
            .filter { entry in entry.editionId == nil || ids == nil || ids!.contains(entry.editionId!) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        let view = HistoryMode(rawValue: viewRaw) ?? .timeline
        VStack(alignment: .leading, spacing: 16) {
            Picker("History view", selection: $viewRaw) {
                ForEach(HistoryMode.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            if entries.isEmpty {
                EmptyBox(message: "No history yet for this title.")
            } else {
                switch view {
                case .timeline: HistoryTimeline(detail: detail, entries: entries)
                case .lifecycle: HistoryLifecycle(detail: detail, entries: entries)
                case .insights: HistoryInsights(entries: entries)
                }
            }
        }
        .detailAnimation(.easeInOut(duration: 0.2), value: viewRaw)
    }
}

// MARK: - Timeline

private struct HistoryTimeline: View {
    let detail: ItemDetail
    let entries: [HistoryEntry]

    private var days: [(String, [HistoryEntry])] {
        var out: [(String, [HistoryEntry])] = []
        let cal = Calendar.current
        for entry in entries {
            let date = DetailText.instant(entry.createdAt) ?? .distantPast
            let key: String
            if cal.isDateInToday(date) { key = "TODAY" }
            else if cal.isDateInYesterday(date) { key = "YESTERDAY" }
            else { key = date.formatted(.dateTime.month(.abbreviated).day()) }
            if out.last?.0 == key { out[out.count - 1].1.append(entry) } else { out.append((key, [entry])) }
        }
        return out
    }

    var body: some View {
        let days = days
        VStack(alignment: .leading, spacing: 18) {
            ForEach(days.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 0) {
                    Text(days[i].0)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.3)
                        .foregroundStyle(Theme.dim)
                        .padding(.leading, 4)
                        .padding(.bottom, 10)
                    ForEach(days[i].1) { entry in
                        TimelineRow(detail: detail, entry: entry)
                    }
                }
            }
        }
    }
}

private struct TimelineRow: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let entry: HistoryEntry

    var body: some View {
        let style = eventStyle(entry.eventType)
        HStack(alignment: .top, spacing: 12) {
            // The spine + node.
            ZStack(alignment: .top) {
                Rectangle().fill(Theme.line).frame(width: 2).frame(maxHeight: .infinity)
                Circle()
                    .fill(style.color)
                    .frame(width: 13, height: 13)
                    .padding(3)
                    .background(style.color.opacity(0.18), in: Circle())
                    .padding(.top, 2)
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                FlowRow(spacing: 6, lineSpacing: 4) {
                    Text(style.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let trigger = triggerLabel(entry.grabTrigger) {
                        Label(trigger, systemImage: triggerIcon(entry.grabTrigger))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                    if detail.editions.count > 1, let eid = entry.editionId,
                       let edition = detail.editions.first(where: { $0.id == eid }) {
                        Text(edition.label)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Theme.edition)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 1)
                            .background(Theme.edition.opacity(0.14), in: Capsule())
                    }
                }
                if let title = entry.sourceTitle {
                    Text(title)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let meta = metaLine
                if !meta.isEmpty {
                    Text(meta).font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
                if entry.eventType == "GRABBED", model.me?.can("grab") ?? true {
                    DetailRailButton(systemImage: "arrow.clockwise", label: "Regrab", size: 32, glyph: 15) {
                        Task { await store.regrab(entry) }
                    }
                    .offset(x: -6)
                }
            }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(DetailText.relative(entry.createdAt)).font(.system(size: 12)).foregroundStyle(Theme.mut)
                if let date = DetailText.instant(entry.createdAt) {
                    Text(date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
            }
            .fixedSize()
        }
        .padding(.leading, 4)
    }

    private var metaLine: String {
        var parts: [String] = []
        if let i = entry.indexer { parts.append(i) }
        if let c = entry.downloadClient { parts.append(c) }
        if let q = entry.quality { parts.append(DetailText.quality(q)) }
        if let s = entry.cfScore, entry.eventType != "GRABBED" || s != 0 { parts.append("score \(s >= 0 ? "+" : "")\(s)") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Lifecycle (one lane per edition)

private struct HistoryLifecycle: View {
    let detail: ItemDetail
    let entries: [HistoryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(detail.orderedEditions) { edition in
                let lane = entries.filter { $0.editionId == edition.id }.sorted { $0.createdAt < $1.createdAt }
                VStack(alignment: .leading, spacing: 10) {
                    Text(edition.label).font(.system(size: 13, weight: .heavy)).foregroundStyle(DetailTokens.tier(edition.tier))
                    if lane.isEmpty {
                        Text("No events for this edition.").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    } else {
                        ScrollView(.horizontal) {
                            HStack(spacing: 6) {
                                ForEach(lane) { entry in
                                    let style = eventStyle(entry.eventType)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(style.label).font(.system(size: 11.5, weight: .bold)).foregroundStyle(style.color)
                                        Text(DetailText.relative(entry.createdAt)).font(.system(size: 10.5)).foregroundStyle(Theme.dim)
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(style.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    if entry.id != lane.last?.id {
                                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Theme.dim)
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    let hasFile = detail.isSeries ? detail.fileCount(edition) > 0 : edition.movieFile != nil
                    if !hasFile {
                        Text("No current file").font(.system(size: 11.5)).foregroundStyle(Theme.miss)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
            }
        }
    }
}

// MARK: - Insights

private struct HistoryInsights: View {
    let entries: [HistoryEntry]

    var body: some View {
        let imports = entries.filter { $0.eventType == "IMPORTED" }.sorted { $0.createdAt < $1.createdAt }
        let scores = imports.compactMap(\.cfScore)
        let net = (scores.last ?? 0) - (scores.first ?? 0)
        let grabs = entries.filter { $0.eventType == "GRABBED" }.count
        let failures = entries.filter { $0.eventType.contains("FAILED") }.count
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("NET CF SCORE GAINED").font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(Theme.dim)
                Text("\(net >= 0 ? "+" : "")\(net)")
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundStyle(net > 0 ? Theme.done : Theme.txt)
                if scores.count > 1 {
                    Sparkline(values: scores.map(Double.init)).frame(height: 36)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
            HStack(spacing: 8) {
                stat("Grabs", grabs, Theme.grab)
                stat("Imports", imports.count, Theme.done)
                stat("Failures", failures, Theme.danger)
            }
        }
    }

    private func stat(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)").font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundStyle(color)
            Text(label.uppercased()).font(.system(size: 10, weight: .bold)).tracking(0.5).foregroundStyle(Theme.dim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
    }
}

private struct Sparkline: View {
    let values: [Double]
    @State private var drawn = false

    var body: some View {
        GeometryReader { geo in
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(hi - lo, 1)
            Path { path in
                for (i, v) in values.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .trim(from: 0, to: drawn ? 1 : 0)
            .stroke(Theme.done, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .detailAnimation(.easeOut(duration: 0.8), value: drawn)
        .onAppear { drawn = true }
    }
}

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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if run.isRunning { DetailSpinner(size: 12, color: Theme.grab) } else { DetailDot(color: statusColor, size: 9) }
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
                            .font(.system(size: 10.5, weight: .semibold))
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
