import SwiftUI
import FusionhaKit

extension IssueFormat.Tone {
    var color: Color {
        switch self {
        case .working: return Theme.grab
        case .resolved: return Theme.done
        case .attention: return Theme.miss
        case .neutral: return Theme.mut
        }
    }
}

/// "Verified": a conclusive file check produced this verdict.
struct IssueVerifiedTag: View {
    var body: some View {
        Label("Verified", systemImage: "checkmark.shield.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.done)
    }
}

/// "Checking…" with its staged steps (web `CheckSweep`); plain text under Reduce Motion.
struct IssueCheckSweep: View {
    let label: String
    let stalled: Bool
    let isSeries: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let steps = IssueFormat.sweepSteps(series: isSeries)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if !reduceMotion { ProgressView().controlSize(.small).tint(Theme.grab) }
                Text(stalled ? "Still checking · we’ll let you know" : label)
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
            }
            if !reduceMotion {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    Label(step, systemImage: i < steps.count - 1 ? "checkmark" : "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundStyle(i < steps.count - 1 ? Theme.mut : Theme.txt)
                }
            }
            Text("This usually takes a few seconds.").font(.system(size: 12)).foregroundStyle(Theme.dim)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actWash(Theme.grab, radius: 14, base: Theme.card)
        .accessibilityElement(children: .combine)
    }
}

/// "Here's what we found" (web `VerdictCard`).
struct IssueVerdictCard: View {
    let report: IssueReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Here’s what we found").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer()
                if report.verdictSummary.verified == true && !report.verdictSummary.text.isEmpty { IssueVerifiedTag() }
            }
            Text(report.verdictSummary.text).font(.system(size: 14)).foregroundStyle(Theme.txt)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actWash(Theme.done, radius: 14, base: Theme.card)
    }
}

/// The verdict at the head of a fix (web `FixVerdict`): the sentence, the
/// situation's detail, and an icon and wash from the state and situation.
struct IssueFixVerdict: View {
    let report: IssueReport

    var body: some View {
        let look = IssueFormat.verdictLook(report)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: look.symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(look.tone.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(report.verdictSummary.text).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.txt)
                if let detail = IssueFormat.situation(report.situation)?.detail {
                    Text(detail).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
                if report.verdictSummary.verified == true { IssueVerifiedTag() }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .actWash(look.tone.color, radius: 14, base: Theme.card)
    }
}

/// The keep-old fix's steps (web `FixProgress`): the verdict, "Your current
/// copy stays" while it does, then done / now / todo / fail.
struct IssueFixProgressView: View {
    let report: IssueReport

    var body: some View {
        if let progress = report.fixProgress {
            VStack(alignment: .leading, spacing: 12) {
                IssueFixVerdict(report: report)
                if progress.keepsCurrent {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(Theme.mut)
                        (Text("Your current copy stays").bold() + Text(" until the new one has downloaded and passed its check."))
                            .font(.system(size: 12.5)).foregroundStyle(Theme.txt)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(progress.steps, id: \.key) { step in stepRow(step) }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Fix progress")
                if let note = IssueFormat.situation(report.situation)?.note {
                    Text(note).font(.system(size: 12)).foregroundStyle(Theme.dim)
                }
            }
        }
    }

    private func stepRow(_ step: IssueFixProgress.Step) -> some View {
        let tint: Color = step.state == "done" ? Theme.done : (step.state == "fail" ? Theme.danger : (step.state == "now" ? Theme.grab : Theme.dim))
        return HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(step.state == "todo" ? 0.12 : 0.2))
                Image(systemName: step.state == "done" ? "checkmark" : (step.state == "fail" ? "xmark" : "circle.fill"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label).font(.system(size: 13.5, weight: step.state == "now" ? .bold : .medium))
                    .foregroundStyle(step.state == "todo" ? Theme.mut : Theme.txt)
                if let sub = step.sub { Text(sub).font(.system(size: 12)).foregroundStyle(Theme.mut) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(step.state == "now" ? "In progress" : step.state)
    }
}

/// The client can't check files (web `HonestNote`).
struct IssueHonestNote: View {
    let adminLooks: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").font(.system(size: 16)).foregroundStyle(Theme.grab)
            VStack(alignment: .leading, spacing: 3) {
                Text("Automatic file checks need fusionha’s decypharr build").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                Text(adminLooks ? "We can’t look inside this file ourselves, so an admin needs to." : "We can’t look inside this file ourselves.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actWash(Theme.grab, radius: 12, base: Theme.card)
    }
}
