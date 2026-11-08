import SwiftUI
import FusionhaKit

/// The reporter's issue thread on v2 (look-pass mock `issueThread`, family
/// 4). It follows the request thread: the header (clean poster, title, the
/// state, the version's media badge, "Won't play · S01E06"), a banner that
/// says what is happening, the fixes as rows, "Or tell the admin", how many
/// others reported it with "Didn't help?", then the thread. The composer
/// stays the sheet's (`IssueThreadSheet`). Only what `GET /issues/{id}`
/// already sends.
struct V2IssueThreadContent: View {
    let issue: MediaIssue
    let events: [RequestThreadEvent]
    let onChanged: () -> Void

    private var reports: [IssueReport] { issue.reports ?? [] }
    /// The viewer's own reports, else every report (a manager opening it).
    private var cards: [IssueReport] {
        let mine = reports.filter { $0.mine == true }
        return mine.isEmpty ? reports : mine
    }
    private var reopenCount: Int { issue.reopenCount ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            V2IssueThreadHeader(issue: issue, lead: cards.first)
            if let lead = cards.first { V2IssueBanner(report: lead, reopenCount: reopenCount) }
            ForEach(cards) { report in reportBlock(report) }
            footer
            sectionLabel("Thread")
            RequestConversation(events: events.filter { !IssueFormat.isMarkerLine($0) }, loaded: true, joinedView: false)
        }
    }

    /// One report's part: its fix in progress, or the fixes to choose from,
    /// then the note to the admin while it is still open. Several reports
    /// each get a line naming the problem and version first.
    @ViewBuilder
    private func reportBlock(_ r: IssueReport) -> some View {
        let fixing = r.state != "RESOLVED" && r.fixProgress != nil
        let open = r.state != "RESOLVED"
        VStack(alignment: .leading, spacing: 10) {
            if cards.count > 1 {
                HStack(spacing: 8) {
                    Text(IssueFormat.problemLabel(r.problem)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let tier = r.version.tier { RequestTierBadges(tiers: [tier], states: [tier: .onDisk]) }
                    Spacer(minLength: 0)
                    V2IssueStateChip(state: r.state)
                }
            }
            if fixing {
                IssueFixProgressView(report: r)
            } else if open && !r.choices.isEmpty {
                if IssueFormat.isLanguageReport(r) {
                    IssueLanguageChoices(issueId: issue.id, report: r, onChanged: onChanged)
                } else {
                    sectionLabel("Choose a fix")
                    V2IssueFixRows(issueId: issue.id, report: r, onChanged: onChanged)
                }
            }
            if open {
                sectionLabel(r.choices.isEmpty || fixing ? "Tell the admin" : "Or tell the admin")
                V2TellAdminRow(issueId: issue.id, reportId: r.id)
            }
        }
    }

    /// "1 other person reported this too." on the left, "Didn't help?" on
    /// the right once the lead report is resolved.
    @ViewBuilder
    private var footer: some View {
        let others = max((issue.participantsCount ?? 1) - 1, 0)
        let resolved = cards.first(where: { $0.state == "RESOLVED" })
        if others > 0 || resolved != nil {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if others > 0 {
                    Text("\(others == 1 ? "1 other person" : "\(others) other people") reported this too.")
                        .font(.system(size: 14)).foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 0)
                if let resolved {
                    V2DidntHelpLink(issueId: issue.id, reportId: resolved.id, onDone: onChanged)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The head: clean poster, title, then the state, the reported version's
/// media badge and "Won't play · S01E06".
struct V2IssueThreadHeader: View {
    let issue: MediaIssue
    let lead: IssueReport?

    var body: some View {
        let title = issue.mediaTitle ?? "Report"
        HStack(alignment: .top, spacing: 14) {
            ActPoster(url: issue.poster, title: title, size: .md)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 8) {
                    V2IssueStateChip(state: issue.state == "RESOLVED" ? "RESOLVED" : (lead?.state ?? issue.state ?? "OPEN"),
                                     reopenCount: issue.reopenCount ?? 0)
                    if let tier = lead?.version.tier {
                        // The reported copy is on disk; the badge names the version.
                        RequestTierBadges(tiers: [tier], states: [tier: .onDisk])
                    }
                    Text(problemLine).font(.system(size: 14)).foregroundStyle(Theme.mut).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// "Won't play · S01E06" (the scope left out for the whole title).
    private var problemLine: String {
        var parts: [String] = []
        if let lead { parts.append(IssueFormat.problemLabel(lead.problem)) }
        if issue.scope != "item" { parts.append(issue.scopeLabel) }
        return parts.joined(separator: " · ")
    }
}

/// What is happening, in words: "Open · the link to this file looked dead
/// once", the situation's detail, then what to do next. Solid content.
struct V2IssueBanner: View {
    let report: IssueReport
    let reopenCount: Int

    var body: some View {
        let state = IssueFormat.stateLabel(report.state, reopenCount: reopenCount)
        let verdict = report.verdictSummary.text
        let hint = IssueFormat.bannerHint(report.state)
        VStack(alignment: .leading, spacing: 6) {
            Text(verdict.isEmpty ? state : "\(state) · \(verdict)")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
            if let detail = IssueFormat.situation(report.situation)?.detail {
                Text(detail).font(.system(size: 15)).foregroundStyle(Theme.txt)
            }
            if !hint.isEmpty {
                Text(hint).font(.system(size: 14)).foregroundStyle(Theme.mut).padding(.top, 2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The state as a quiet capsule. Checking and Fixing are active (the
/// accent); everything else is the muted ink. Orange is kept for the owner.
struct V2IssueStateChip: View {
    let state: String
    var reopenCount = 0

    var body: some View {
        let active = IssueFormat.isWorking(state)
        Text(IssueFormat.stateLabel(state, reopenCount: reopenCount))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(active ? Theme.accentText : Theme.mut)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background((active ? Theme.i1 : Theme.mut).opacity(0.16), in: Capsule())
            .fixedSize()
    }
}
