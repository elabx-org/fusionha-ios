import SwiftUI
import FusionhaKit

/// A reporter's issue thread (web `IssueThread`): the state banner, their own
/// report cards (fix progress, the fixes on offer, "Didn't help?"), how many
/// others reported it, the conversation (rescan markers left out, marked read
/// as it arrives) and a message box. The issue polls every 15 s, lines every 5 s.
struct IssueThreadSheet: View {
    let issueId: Int
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var issue: MediaIssue?
    @State private var events: [RequestThreadEvent] = []
    @State private var marked = 0
    @State private var tick = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let issue { loaded(issue) } else { DiscoverEmptyState(message: "Loading…") }
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) {
                if issue != nil {
                    RequestThreadComposer(placeholder: "Add detail for the admins…",
                                          post: { [issueId] client, body in try await client.postIssueMessage(id: issueId, body: body) }) { line in
                        append([line])
                    }
                }
            }
            .background(Theme.bg)
            .navigationTitle(issue?.mediaTitle ?? "Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
        .task(id: tick) { await pollIssue() }
        .task { await pollLines() }
    }

    @ViewBuilder
    private func loaded(_ issue: MediaIssue) -> some View {
        let reports = issue.reports ?? []
        let mine = reports.filter { $0.mine == true }
        let cards = mine.isEmpty ? reports : mine
        let others = max((issue.participantsCount ?? 1) - 1, 0)
        HStack(spacing: 8) {
            IssueStateChip(state: issue.state ?? "OPEN", reopenCount: issue.reopenCount ?? 0)
            ForEach(Array(Set(cards.compactMap(\.version.tier))).sorted { $0.rawValue < $1.rawValue }, id: \.self) { ActTierChip(tier: $0) }
        }
        if let lead = cards.first {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(IssueFormat.stateLabel(lead.state, reopenCount: issue.reopenCount ?? 0)) · \(lead.verdictSummary.text)")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                Text(IssueFormat.bannerHint(lead.state)).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .actWash(IssueFormat.stateTone(lead.state, reopenCount: issue.reopenCount ?? 0).color, radius: 12, base: Theme.card)
        }
        label("Reports")
        ForEach(cards) { r in reportCard(issue.id, r) }
        if others > 0 {
            Text("\(others == 1 ? "1 other person" : "\(others) other people") reported this too.")
                .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
        }
        label("Thread")
        RequestConversation(events: events.filter { !IssueFormat.isMarkerLine($0) }, loaded: true, joinedView: false)
    }

    private func reportCard(_ issueId: Int, _ r: IssueReport) -> some View {
        let fixing = r.state != "RESOLVED" && r.fixProgress != nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(IssueFormat.problemLabel(r.problem)).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                if let tier = r.version.tier { ActTierChip(tier: tier) }
                Spacer()
                IssueStateChip(state: r.state)
            }
            if fixing {
                IssueFixProgressView(report: r)
            } else {
                Text(r.verdictSummary.text).font(.system(size: 13)).foregroundStyle(Theme.txt)
            }
            if r.state != "RESOLVED" && !fixing && !r.choices.isEmpty {
                if IssueFormat.isLanguageReport(r) {
                    IssueLanguageChoices(issueId: issueId, report: r) { tick += 1 }
                } else {
                    IssueChoiceList(issueId: issueId, report: r) { tick += 1 }
                }
            }
            if r.state == "RESOLVED" { IssueReopenButton(issueId: issueId, reportId: r.id) { tick += 1 } }
        }
        .padding(12)
        .actWash(IssueFormat.stateTone(r.state).color, radius: 14, base: Theme.card)
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
    }

    // MARK: Polling

    private func pollIssue() async {
        while !Task.isCancelled {
            if let client = model.client, let fresh = try? await client.issue(id: issueId) { issue = fresh }
            try? await Task.sleep(for: .seconds(15))
        }
    }

    private func pollLines() async {
        while !Task.isCancelled {
            if let client = model.client, let fresh = try? await client.issueEvents(id: issueId, afterId: events.last?.id ?? 0) {
                append(fresh)
                if let last = events.last?.id, last > marked, model.me != nil {
                    marked = last
                    try? await client.markIssueRead(id: issueId, lastEventId: last)
                }
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func append(_ lines: [RequestThreadEvent]) {
        let known = Set(events.map(\.id))
        let fresh = lines.filter { !known.contains($0.id) }
        if !fresh.isEmpty { events = (events + fresh).sorted { $0.id < $1.id } }
    }
}
