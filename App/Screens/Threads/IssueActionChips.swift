import SwiftUI
import FusionhaKit

enum StagedDialogKind: String, Hashable { case use, discard, regrab, resolve }

struct StagedDialogRoute: Identifiable, Hashable {
    let kind: StagedDialogKind
    let report: IssueReport?
    var id: String { "\(kind.rawValue)-\(report?.id ?? 0)" }
}

/// The manager's actions on an issue (web `IssueChips` + `FileActionChips`):
/// the linked request's Approve / Decline, Add 4K where offered, Search
/// missing, Ask Plex to rescan, Use / Discard the new copy, Re-grab, Find a
/// release, and Resolve. A chip that's off says why.
struct IssueActionChips: View {
    let issue: MediaIssue
    let linked: MediaRequest?
    let manager: Bool
    let onDialog: (StagedDialogRoute) -> Void
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @State private var working = false
    @State private var declining: MediaRequest?

    var body: some View {
        let resolved = issue.state == "RESOLVED"
        let reports = issue.reports ?? []
        if !resolved || linked != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIONS").font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
                ActFlow(spacing: 8, lineSpacing: 8) {
                    if let linked {
                        chip("Approve", "checkmark", primary: true) { await approve(linked) }
                        chip("Decline", "xmark", danger: true) { declining = linked }
                    }
                    if !resolved {
                        if let offer = IssueChipRules.fourKOffer(reports) {
                            chip("Add 4K", "plus", off: offer.choice.allowed ? off(offer.report) : IssueFormat.permissionHint(offer.choice.permission, manager: true)) {
                                await act(offer.report, "request_version")
                            }
                        }
                        if reports.contains(where: { $0.problem == "MISSING_EPS" }) {
                            let r = IssueChipRules.actionReport(reports, problem: "MISSING_EPS")
                            chip("Search missing", "magnifyingglass", off: off(r)) { await act(r, "search_missing") }
                        }
                        if reports.contains(where: { $0.problem == "NOT_IN_PLEX" }) {
                            let r = IssueChipRules.actionReport(reports, problem: "NOT_IN_PLEX")
                            chip("Ask Plex to rescan", "arrow.clockwise", off: off(r)) { await act(r, "plex_rescan") }
                        }
                        if manager { fileChips(reports) }
                        chip("Resolve", "checkmark.circle") { onDialog(StagedDialogRoute(kind: .resolve, report: nil)) }
                    }
                }
            }
            .sheet(item: $declining) { r in RejectDialog(request: r) { onChanged() } }
        }
    }

    @ViewBuilder
    private func fileChips(_ reports: [IssueReport]) -> some View {
        ForEach(IssueChipRules.fileOffers(issue), id: \.kind) { o in
            switch o.kind {
            case .use:
                chip("Use new copy", "arrow.left.arrow.right", primary: true, off: StagedFacts.stagedReason(o.report, use: true)) {
                    onDialog(StagedDialogRoute(kind: .use, report: o.report))
                }
            case .discard:
                chip(o.report.stagedCopy?.stuck != nil ? "Discard new copy again" : "Discard new copy", "trash", danger: true,
                     off: StagedFacts.stagedReason(o.report, use: false)) {
                    onDialog(StagedDialogRoute(kind: .discard, report: o.report))
                }
            case .regrab:
                let why = StagedFacts.regrabReason(o.report, o.choice) ?? (reports.contains { $0.state == "FIXING" } ? "A fix is already running" : nil)
                chip("Re-grab", "arrow.clockwise", off: why) { onDialog(StagedDialogRoute(kind: .regrab, report: o.report)) }
            case .find:
                chip("Find a release", "magnifyingglass", off: StagedFacts.findReason(o.choice)) { await act(o.report, "find_language_release") }
            }
        }
    }

    /// A fix chip is off on no report, a resolved or checking one, or while one runs.
    private func off(_ r: IssueReport?) -> String? {
        guard let r else { return "Not available" }
        if r.state == "RESOLVED" { return "Already resolved" }
        if r.state == "CHECKING" { return "Still checking" }
        return nil
    }

    private func chip(_ label: String, _ symbol: String, primary: Bool = false, danger: Bool = false, off: String? = nil,
                      action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Label(label, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primary ? Theme.onAccent : (danger ? Theme.danger : Theme.txt))
                .padding(.horizontal, 12).frame(height: 36)
                .background(primary ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.panel2), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(off != nil || working)
        .opacity(off != nil ? 0.5 : 1)
        .accessibilityHint(off ?? "")
    }

    private func act(_ report: IssueReport?, _ action: String) async {
        guard let report, let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            try await client.issueAction(issueId: issue.id, reportId: report.id, action: action)
            model.toast(action == "find_language_release" ? "Looking for a release" : "Started")
            onChanged()
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not start that fix", variant: .error)
        }
    }

    private func approve(_ r: MediaRequest) async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            try await client.approveRequest(id: r.id, body: ApproveBody(editions: [], search: false))
            model.toast("Request approved")
            onChanged()
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not decide request", variant: .error)
        }
    }
}
