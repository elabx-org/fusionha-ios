import SwiftUI
import FusionhaKit

/// One search run (mock browse-title.js `runCard`): its kind and trigger
/// tag, when it ran, then "4,217 releases checked · 4 for this title · 1
/// grabbed · 4 skipped · 9 min": checked is the whole run's, the rest are
/// this title's candidates (`GET /api/v1/system/runs/{id}`, loaded here). A
/// run that considered releases opens its decision trail (`V2RunTrail`) on
/// a tap. A W1 card.
struct V2SearchRunCard: View {
    @Environment(\.pagePalette) private var page
    @Environment(\.detailReduceMotion) private var reduce
    @Environment(AppModel.self) private var model
    let run: ActivityRun
    let detail: ItemDetail
    @State private var open: Bool
    @State private var mine: [RunCandidate]?
    @State private var failed = false

    init(run: ActivityRun, detail: ItemDetail, startsOpen: Bool = false) {
        self.run = run
        self.detail = detail
        _open = State(initialValue: startsOpen)
    }

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var expandable: Bool { run.releases > 0 || run.evaluated > 0 }
    /// The run was this title's own search: its counters are this title's.
    private var own: Bool { run.itemId == detail.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                VStack(alignment: .leading, spacing: 4) {
                    head
                    facts
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!expandable)
            .accessibilityHint(expandable ? (open ? "Hides the decision trail" : "Shows the decision trail") : "")
            if open && expandable {
                Rectangle().fill(ink.opacity(0.12)).frame(height: 0.5).padding(.vertical, 10)
                V2RunTrail(detail: detail, candidates: mine, failed: failed)
                    .transition(.opacity)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 18) }
        .task(id: run.id) {
            guard expandable, run.status != "running" else { return }
            do {
                guard let detailRun = try await model.client?.systemRun(id: run.id) else { return }
                mine = V2RunTrail.mine(detailRun, detail: detail)
            } catch {
                failed = true
            }
        }
    }

    private func toggle() {
        if reduce { open.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } }
    }

    private var head: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(run.status == "failed" ? Theme.danger : ink)
            Text(run.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
            if let trigger = triggerLabel(run.trigger) {
                V2ReleaseCard.filledTag(Text(trigger.lowercased()), color: muted).lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(Self.when(run.endedAt ?? run.startedAt))
                .font(.system(size: 12.5))
                .monospacedDigit()
                .foregroundStyle(muted)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var icon: String {
        if run.status == "failed" { return "exclamationmark.circle" }
        return run.trigger == "rss" ? "dot.radiowaves.up.forward" : "magnifyingglass"
    }

    private var facts: some View {
        var text = Text("")
        var first = true
        func add(_ part: Text) {
            text = first ? part : text + Text(" · ") + part
            first = false
        }
        if run.status == "failed" {
            add(Text("Failed").foregroundColor(Theme.danger))
            if run.errors > 0 { add(Text("\(run.errors) error\(run.errors == 1 ? "" : "s")")) }
        } else if run.status == "running" {
            add(Text(TasksLogic.factualLine(run)))
        } else {
            add(Text("\(run.releases.formatted()) release\(run.releases == 1 ? "" : "s") checked"))
            if let mine {
                let grabbed = mine.filter { $0.action == "GRAB" || $0.action == "UPGRADE" }.count
                let skipped = mine.filter { $0.action == "REJECT" || $0.action == "SKIP" }.count
                add(Text("\(mine.count) for this title"))
                if grabbed > 0 { add(Text("\(grabbed) grabbed").bold().foregroundColor(Theme.doneText)) }
                if skipped > 0 { add(Text("\(skipped) skipped")) }
            } else if own {
                // Until the candidates load, a title's own run can show its counters.
                if run.grabbed > 0 { add(Text("\(run.grabbed) grabbed").bold().foregroundColor(Theme.doneText)) }
                if run.upgraded > 0 { add(Text("\(run.upgraded) upgraded").bold().foregroundColor(Theme.doneText)) }
                if run.rejected > 0 { add(Text("\(run.rejected.formatted()) skipped")) }
            }
            if run.releases == 0, run.skippedInFlight == true { add(Text("already downloading")) }
        }
        if let ms = run.durationMs, ms > 0 { add(Text(TasksLogic.duration(Double(ms) / 1000))) }
        return text
            .font(.system(size: 12.5))
            .foregroundStyle(muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "Today 16:11" / "Thu 29 Oct 15:43".
    static func when(_ iso: String) -> String {
        guard let date = DetailText.instant(iso) else { return "" }
        let time = date.formatted(.dateTime.hour().minute())
        if Calendar.current.isDateInToday(date) { return "Today \(time)" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday \(time)" }
        return "\(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) \(time)"
    }
}
