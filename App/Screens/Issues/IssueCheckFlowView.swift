import SwiftUI
import FusionhaKit

/// After a report is filed (web `IssueCheckFlow`): the sweep while it's
/// CHECKING (2 s polls; "Still checking" after 60 s per check), then the
/// verdict with the fixes on offer and a note for the admin, the keep-old
/// fix's progress while FIXING (15 s polls), or the resolved card with
/// "Didn't help?".
struct IssueCheckFlowView: View {
    let issueId: Int
    let reportId: Int
    let isSeries: Bool
    @Environment(AppModel.self) private var model
    @State private var report: IssueReport?
    @State private var failed = false
    @State private var stalled = false
    @State private var watchedGeneration: Int?
    @State private var checkStarted = Date()

    var body: some View {
        content
            .task { await poll() }
    }

    @ViewBuilder
    private var content: some View {
        if failed && report == nil {
            Text("Could not load this report.").font(.system(size: 13)).foregroundStyle(Theme.mut)
        } else if let report {
            let waiting = report.state == "CHECKING" && report.situation == "second_check"
            if waiting {
                IssueFixVerdict(report: report)
            } else if report.state == "FIXING", report.fixProgress != nil {
                IssueFixProgressView(report: report)
            } else if IssueFormat.isWorking(report.state) {
                IssueCheckSweep(label: report.state == "FIXING" ? "Fixing…" : "Checking…",
                                stalled: stalled && report.state == "CHECKING", isSeries: isSeries)
            } else if report.state == "RESOLVED" {
                resolved(report)
            } else {
                verdict(report)
            }
        } else {
            IssueCheckSweep(label: "Checking…", stalled: false, isSeries: isSeries)
        }
    }

    private func resolved(_ report: IssueReport) -> some View {
        let swapped = report.fixProgress?.steps.contains { $0.key == "swap" && $0.state == "done" } == true
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.done)
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.verdictSummary.text.isEmpty ? "Resolved" : report.verdictSummary.text)
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                    if report.verdictSummary.verified == true { IssueVerifiedTag() }
                    Text(swapped ? "It’s in your library now. Plex may need a minute to show it." : "We’ll tell you if anything else is needed.")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .actWash(Theme.done, radius: 14, base: Theme.card)
            IssueReopenButton(issueId: issueId, reportId: report.id) { Task { await refresh() } }
        }
    }

    @ViewBuilder
    private func verdict(_ report: IssueReport) -> some View {
        let noChecks = report.verdictSummary.code == "needs_decypharr"
        let needsAdmin = report.state == "NEEDS_ADMIN"
        let look = IssueFormat.situation(report.situation)
        VStack(alignment: .leading, spacing: 14) {
            if report.fixProgress != nil {
                IssueFixProgressView(report: report)
                IssueReportBox(issueId: issueId, reportId: report.id, label: "Add detail for the admin", button: "Send")
            } else if !report.choices.isEmpty && IssueFormat.isLanguageReport(report) {
                IssueLanguageChoices(issueId: issueId, report: report) { Task { await refresh() } }
            } else if !report.choices.isEmpty {
                IssueVerdictCard(report: report)
                if noChecks { IssueHonestNote(adminLooks: needsAdmin) }
                IssueChoiceList(issueId: issueId, report: report) { Task { await refresh() } }
                IssueReportBox(issueId: issueId, reportId: report.id)
            } else if needsAdmin && noChecks {
                IssueHonestNote(adminLooks: true)
                IssueReportBox(issueId: issueId, reportId: report.id, label: "Tell the admin what happened")
            } else {
                if look != nil && needsAdmin { IssueFixVerdict(report: report) } else { IssueVerdictCard(report: report) }
                if needsAdmin {
                    Text(look?.note ?? "There’s nothing to choose here. We’ve sent it to an admin.")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
                IssueReportBox(issueId: issueId, reportId: report.id, label: "Add detail for the admin", button: "Send")
            }
        }
    }

    // MARK: Polling

    private func poll() async {
        while !Task.isCancelled {
            await refresh()
            guard let report else {
                try? await Task.sleep(for: .seconds(2))
                continue
            }
            let waiting = report.state == "CHECKING" && report.situation == "second_check"
            let checking = report.state == "CHECKING" && !waiting
            if checking {
                if watchedGeneration != report.checkGeneration {
                    watchedGeneration = report.checkGeneration
                    checkStarted = Date()
                    stalled = false
                }
                if Date().timeIntervalSince(checkStarted) > 60 { stalled = true }
                try? await Task.sleep(for: .seconds(stalled ? 15 : 2))
            } else {
                try? await Task.sleep(for: .seconds(report.state == "FIXING" || waiting ? 15 : 30))
            }
        }
    }

    private func refresh() async {
        guard let client = model.client else { return }
        do {
            let issue = try await client.issue(id: issueId)
            report = issue.reports?.first { $0.id == reportId }
            failed = false
        } catch is CancellationError {
        } catch {
            failed = true
        }
    }
}
