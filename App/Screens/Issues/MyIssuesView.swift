import SwiftUI
import FusionhaKit

/// "My issues" (web `MyIssues`): the caller's reports, newest activity first,
/// as cards washed by their state; a card opens its thread. Refreshes every 15 s.
struct MyIssuesView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [MediaIssue] = []
    @State private var cursor: String?
    @State private var loaded = false
    @State private var failed = false
    @State private var open: MediaIssue?

    var body: some View {
        content
            .task {
                while !Task.isCancelled {
                    await load()
                    try? await Task.sleep(for: .seconds(15))
                }
            }
            .sheet(item: $open) { issue in IssueThreadSheet(issueId: issue.id) }
    }

    @ViewBuilder
    private var content: some View {
        if !loaded {
            DiscoverEmptyState(message: "Loading your reports…")
        } else if failed && items.isEmpty {
            DiscoverEmptyState(message: "Could not load your reports.")
        } else if items.isEmpty {
            DiscoverEmptyState(message: "No reports yet.")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(items) { issue in
                    Button { open = issue } label: { IssueCardRow(issue: issue) }.buttonStyle(.plain)
                }
                if cursor != nil {
                    Button("Load more") { Task { await loadMore() } }.buttonStyle(.discover(.subtle))
                }
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let page = try await client.issuesPage(mine: true)
            let firstIds = Set(page.items.map(\.id))
            let beyond = items.dropFirst(page.items.count).filter { !firstIds.contains($0.id) }
            items = page.items + beyond
            if beyond.isEmpty { cursor = page.nextCursor }
            failed = false
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }
        loaded = true
    }

    private func loadMore() async {
        guard let client = model.client, let cursor, let page = try? await client.issuesPage(mine: true, cursor: cursor) else { return }
        let known = Set(items.map(\.id))
        items += page.items.filter { !known.contains($0.id) }
        self.cursor = page.nextCursor
    }
}

/// One report as a card: poster, title, problem and version, how many people
/// reported it, the verdict, the state chip and when, with an unread dot.
struct IssueCardRow: View {
    let issue: MediaIssue

    var body: some View {
        let report = IssueFormat.pickReport(issue.reports ?? [])
        let state = issue.state == "RESOLVED" ? "RESOLVED" : (report?.state ?? issue.state ?? "OPEN")
        let reopen = issue.reopenCount ?? 0
        let unread = (issue.thread?.unread ?? 0) > 0
        let title = issue.mediaTitle ?? "Untitled"
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: issue.poster, title: title, size: .md)
            VStack(alignment: .leading, spacing: 5) {
                (Text(title).fontWeight(.semibold) + Text(issue.mediaYear.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                    .font(.system(size: 15)).foregroundStyle(Theme.txt).lineLimit(2)
                if let report {
                    HStack(spacing: 6) {
                        Label(IssueFormat.problemLabel(report.problem), systemImage: IssueFormat.problemSymbol(report.problem))
                            .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                        if let tier = report.version.tier { ActTierChip(tier: tier) }
                    }
                }
                if (issue.participantsCount ?? 0) > 1 {
                    Text("\(issue.participantsCount ?? 0) people reported this").font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
                if let text = report?.verdictSummary.text, !text.isEmpty {
                    Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.txt).lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 6) {
                IssueStateChip(state: state, reopenCount: reopen)
                HStack(spacing: 4) {
                    if unread { Circle().fill(Theme.i2).frame(width: 7, height: 7).accessibilityLabel("Unread") }
                    Text(ActFmt.relative(issue.thread?.lastEventAt ?? issue.createdAt)).font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                }
            }
        }
        .padding(12)
        .actWash(IssueFormat.stateTone(state, reopenCount: reopen).color, radius: 14, base: Theme.card)
        .accessibilityElement(children: .combine)
    }
}

/// Checking / Fixing / Needs an admin / Open / Reopened / Resolved as a tinted chip.
struct IssueStateChip: View {
    let state: String
    var reopenCount = 0

    var body: some View {
        let look = IssueFormat.stateTone(state, reopenCount: reopenCount)
        let tone = look.color
        Text(IssueFormat.stateLabel(state, reopenCount: reopenCount))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(look == .accent ? Theme.accentText : tone)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tone.opacity(0.15), in: Capsule())
            .fixedSize()
    }
}
