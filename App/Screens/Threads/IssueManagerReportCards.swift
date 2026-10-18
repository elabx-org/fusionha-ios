import SwiftUI
import FusionhaKit

extension ThreadBanner.Tone {
    var color: Color {
        switch self {
        case .checking, .fixing: return Theme.grab
        case .needs: return Theme.miss
        case .ok: return Theme.done
        case .neutral: return Theme.mut
        }
    }

    var symbol: String {
        switch self {
        case .checking: return "magnifyingglass"
        case .fixing: return "arrow.clockwise"
        case .needs: return "exclamationmark.triangle"
        case .ok: return "checkmark"
        case .neutral: return "clock"
        }
    }
}

/// Where the thread stands (web `ThreadBanner`), on its wash.
struct IssueThreadBannerView: View {
    let banner: ThreadBanner.Banner

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: banner.symbol ?? banner.tone.symbol)
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(banner.tone.color).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(banner.text).font(.system(size: 14.5, weight: .bold)).foregroundStyle(Theme.txt)
                if banner.verified { Label("Verified by decypharr", systemImage: "server.rack").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.done) }
                Text(banner.detail).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .actWash(banner.tone.color, radius: 14, base: Theme.card)
        .accessibilityElement(children: .combine)
    }
}

/// Each report for a manager (web `ReportCards`): reporter, problem, version,
/// its own state in plain words, the verdict, the old-vs-new compare of a
/// set-aside copy with Use / Discard, a stuck copy's guide, and the evidence.
struct IssueManagerReportCards: View {
    let reports: [IssueReport]
    let manager: Bool
    let onStaged: (StagedDialogKind, IssueReport) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(reports) { r in card(r) }
        }
    }

    private func card(_ r: IssueReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if manager, let who = r.reporter { RequestPersonChip(name: who.displayName, prefix: nil) }
                Label(IssueFormat.problemLabel(r.problem), systemImage: IssueFormat.problemSymbol(r.problem))
                    .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                if let tier = r.version.tier { ActTierChip(tier: tier) }
                Spacer(minLength: 4)
                statePill(r)
            }
            Text(r.verdictSummary.text).font(.system(size: 13)).foregroundStyle(Theme.txt)
            if manager, r.stagedCopy != nil { StagedCompareView(report: r, onStaged: onStaged) }
            if manager, let stuck = r.stagedCopy?.stuck { StuckGuideView(stuck: stuck) }
            if manager { evidence(r) }
        }
        .padding(12)
        .actWash(IssueFormat.stateTone(r.state).color, radius: 14, base: Theme.card)
    }

    private func statePill(_ r: IssueReport) -> some View {
        let (label, color): (String, Color) = {
            if r.guardState == "replacing" { return ("Fixing · keeping the current copy", Theme.i2) }
            if r.guardState == "paused" { return ("Paused", Theme.stuck) }
            switch r.state {
            case "CHECKING": return ("Checking", Theme.i2)
            case "FIXING": return ("Fixing", Theme.i2)
            case "AWAITING_USER": return ("Waiting on reporter", Theme.mut)
            case "NEEDS_ADMIN": return ("Needs an admin", Theme.miss)
            case "RESOLVED": return ("Resolved", Theme.done)
            default: return ("Open", Theme.miss)
            }
        }()
        return Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .lineLimit(1)
    }

    @ViewBuilder
    private func evidence(_ r: IssueReport) -> some View {
        // The app's own wording from the diagnosis; the server's flat list otherwise.
        let walked = EvidenceRows.rows(r.diagnosis?.value)
        let rows = walked.isEmpty ? EvidenceRows.rows(list: r.evidenceList) : walked
        if !rows.isEmpty || r.client != nil {
            DisclosureGroup("Evidence") {
                VStack(alignment: .leading, spacing: 4) {
                    if let client = r.client { row("Client", client.name) }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, kv in row(kv.label, kv.value) }
                }
                .padding(.top, 6)
            }
            .font(.system(size: 12.5, weight: .semibold))
            .tint(Theme.mut)
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(k).font(.system(size: 11.5).monospaced()).foregroundStyle(Theme.dim).frame(width: 120, alignment: .leading)
            Text(v).font(.system(size: 12)).foregroundStyle(Theme.txt).textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

/// The old-vs-new compare of a held keep-old replacement (web `StagedCompare`).
struct StagedCompareView: View {
    let report: IssueReport
    let onStaged: (StagedDialogKind, IssueReport) -> Void

    var body: some View {
        if let staged = report.stagedCopy {
            let useWhy = StagedFacts.stagedReason(report, use: true)
            let discardWhy = StagedFacts.stagedReason(report, use: false)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(StagedFacts.headline(staged.state)).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                    Spacer()
                    if staged.old?.verdict != nil && staged.new.verdict != nil {
                        Label("both checked by decypharr", systemImage: "checkmark.shield").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.done)
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                    GridRow {
                        Text("")
                        Label("Current", systemImage: "doc").font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.mut)
                        Label("New (set aside)", systemImage: "arrow.down.circle").font(.system(size: 11.5, weight: .bold)).foregroundStyle(Theme.grab)
                    }
                    line("Release", staged.old?.release ?? "—", staged.new.release ?? "—", mono: true)
                    line("Quality", staged.old?.quality ?? "—", staged.new.quality ?? "—")
                    line("Size", staged.old.map(StagedFacts.size) ?? "—", StagedFacts.size(staged.new))
                    line("Video", staged.old?.video ?? "—", staged.new.video ?? "—")
                    line("Audio", StagedFacts.list(staged.old?.audioLanguages), StagedFacts.list(staged.new.audioLanguages),
                         better: StagedFacts.addsAudio(staged.old, staged.new))
                    line("Subtitles", StagedFacts.list(staged.old?.subtitleLanguages), StagedFacts.list(staged.new.subtitleLanguages))
                    line("File check", staged.old.map(StagedFacts.checkSentence) ?? "—", StagedFacts.checkSentence(staged.new))
                }
                Text("Use new copy replaces the current one and records it in History. Discard keeps the current copy and removes the set-aside file.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                HStack(spacing: 8) {
                    Spacer()
                    Button(role: .destructive) { onStaged(.discard, report) } label: {
                        Label(staged.stuck != nil ? "Discard again" : "Discard new copy", systemImage: "trash")
                    }
                    .buttonStyle(.discover(.subtle))
                    .disabled(discardWhy != nil)
                    .accessibilityHint(discardWhy ?? "")
                    Button { onStaged(.use, report) } label: { Label("Use new copy", systemImage: "arrow.left.arrow.right") }
                        .buttonStyle(.discover(.primary))
                        .disabled(useWhy != nil)
                        .accessibilityHint(useWhy ?? "")
                }
                if let why = useWhy ?? discardWhy {
                    Text(why).font(.system(size: 11.5)).foregroundStyle(Theme.mut).frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(12)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func line(_ k: String, _ a: String, _ b: String, mono: Bool = false, better: Bool = false) -> some View {
        GridRow {
            Text(k).font(.system(size: 11.5)).foregroundStyle(Theme.dim)
            Text(a).font(mono ? .system(size: 11).monospaced() : .system(size: 12)).foregroundStyle(Theme.txt).lineLimit(mono ? 3 : 2)
            Text(b).font(mono ? .system(size: 11).monospaced() : .system(size: 12, weight: better ? .bold : .regular))
                .foregroundStyle(better ? Theme.done : Theme.txt).lineLimit(mono ? 3 : 2)
        }
    }
}

/// A stuck set-aside copy's "What to do" (web `StuckGuide`).
struct StuckGuideView: View {
    let stuck: IssueStagedCopy.Stuck

    var body: some View {
        let root = stuck.rootName.map { "the \($0) root folder" } ?? "the version’s root folder"
        VStack(alignment: .leading, spacing: 6) {
            Label("What to do", systemImage: "info.circle").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
            if stuck.reason == "no_root" {
                (Text("1. Restore \(root). ").bold() + Text("Settings › Media › Root folders: re-add or re-point it (or remount the share)."))
            }
            (Text("\(stuck.reason == "no_root" ? "2" : "1"). Discard new copy again. ").bold() + Text("fusionha retries the removal; if the file is gone from every root, it clears the row and records it."))
            (Text("Then ") + Text("Re-grab").bold() + Text(" or ") + Text("Resolve").bold() + Text(". Use new copy stays off: a stuck copy is never swapped in."))
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.txt)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// One line per group of fix grabs since the thread opened (web `HistoryStrip`).
struct IssueHistoryStrips: View {
    let grabs: IssueFixGrabs
    let fallbackTitle: String
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 6) {
            ForEach(grabs.groups, id: \.self) { g in
                let title = grabs.title ?? fallbackTitle
                let shown = g.labels.prefix(3).joined(separator: ", ")
                let subject = shown.isEmpty ? title : "\(title) \(shown)\(g.labels.count > 3 ? " +\(g.labels.count - 3) more" : "")"
                HStack(spacing: 8) {
                    Image(systemName: "clock").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    Text("History").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    Text(g.status == "grabbed" ? "\(subject) · grabbed" : subject).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if g.status != "grabbed" {
                        Text(g.status).font(.system(size: 11.5, weight: .bold)).foregroundStyle(g.status == "failed" ? Theme.danger : Theme.done)
                    }
                    Spacer(minLength: 4)
                    Label(g.trigger == "autofix" ? "Auto-fix" : "Self-service", systemImage: g.trigger == "autofix" ? "bolt.fill" : "person.fill")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.grab)
                }
                .padding(10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}
