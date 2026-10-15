import SwiftUI
import FusionhaKit

/// "Choose a fix" (web `ChoiceList`): each offered fix is a button; one the
/// viewer can't take stays visible, dimmed, with the reason under it.
struct IssueChoiceList: View {
    let issueId: Int
    let report: IssueReport
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @State private var started: String?
    @State private var done: Set<String> = []

    private var manager: Bool { model.me?.hasPermission("issues.manage") ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHOOSE A FIX").font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
            ForEach(report.choices) { c in row(c) }
        }
    }

    private func row(_ c: IssueChoice) -> some View {
        let look = IssueFormat.choiceButton(c.id)
        let hint = c.allowed ? c.sub : IssueFormat.disabledSub(c.permission, manager: manager, choiceId: c.id, dailyLimit: c.dailyLimit)
        let label = started == c.id ? "Starting…" : (done.contains(c.id) ? look.done : look.text)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(c.label).font(.system(size: 14, weight: .semibold)).foregroundStyle(c.allowed ? Theme.txt : Theme.mut)
                if let hint, !hint.isEmpty { Text(hint).font(.system(size: 12)).foregroundStyle(Theme.mut) }
            }
            Spacer(minLength: 6)
            Button { Task { await run(c) } } label: { Label(label, systemImage: look.symbol) }
                .buttonStyle(.discover(c.allowed ? DiscoverButtonKind.primary : DiscoverButtonKind.subtle))
                .disabled(!c.allowed || started != nil || done.contains(c.id))
                .accessibilityHint(c.allowed ? "" : IssueFormat.permissionHint(c.permission, manager: manager, choiceId: c.id, dailyLimit: c.dailyLimit))
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(c.allowed ? 1 : 0.75)
    }

    private func run(_ c: IssueChoice) async {
        guard let client = model.client else { return }
        started = c.id
        defer { started = nil }
        do {
            try await client.issueAction(issueId: issueId, reportId: report.id, action: c.id)
            done.insert(c.id)
            onChanged()
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not start that fix", variant: .error)
        }
    }
}

/// The language fix (web `LanguageChoices`): the check's own diagnosis line,
/// then "find a release with the right audio" (counted, with what's left
/// today) or "keep this copy and tell the admin" (never counted).
struct IssueLanguageChoices: View {
    let issueId: Int
    let report: IssueReport
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @State private var diagnosis: String?
    @State private var started: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let diagnosis {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "character.bubble").font(.system(size: 16)).foregroundStyle(Theme.mut)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(diagnosis).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                        if report.verdictSummary.verified == true { IssueVerifiedTag() }
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Text(report.verdictSummary.text).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
            ForEach(report.choices) { c in choice(c) }
        }
        .task { await loadDiagnosis() }
    }

    private func choice(_ c: IssueChoice) -> some View {
        let hint = c.id == "keep_copy"
            ? "\(c.sub ?? "Nothing changes") · doesn’t count against your limit"
            : (c.allowed ? c.sub : IssueFormat.disabledSub(c.permission, choiceId: c.id, dailyLimit: c.dailyLimit))
        return Button { Task { await run(c) } } label: {
            HStack(spacing: 10) {
                Image(systemName: c.id == "find_language_release" ? "magnifyingglass" : "bubble.left")
                    .font(.system(size: 15)).foregroundStyle(Theme.grab).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(started == c.id ? "Starting…" : c.label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let hint { Text(hint).font(.system(size: 12)).foregroundStyle(Theme.mut).multilineTextAlignment(.leading) }
                }
                Spacer(minLength: 4)
                if let left = c.left, let limit = c.dailyLimit {
                    (Text("\(left)").bold() + Text(" of \(limit) left today")).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                }
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!c.allowed || started != nil)
        .opacity(c.allowed ? 1 : 0.7)
    }

    private func loadDiagnosis() async {
        guard let client = model.client, let events = try? await client.issueEvents(id: issueId) else { return }
        diagnosis = events.reversed().first { $0.eventType == "verdict" && $0.data?.reportId == report.id }?.body
    }

    private func run(_ c: IssueChoice) async {
        guard let client = model.client else { return }
        started = c.id
        defer { started = nil }
        do {
            try await client.issueAction(issueId: issueId, reportId: report.id, action: c.id)
            onChanged()
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not start that fix", variant: .error)
        }
    }
}

/// "Tell the admin": an optional note, then ask-admin on this report (web `ReportBox`).
struct IssueReportBox: View {
    let issueId: Int
    let reportId: Int
    var label = "Or tell the admin"
    var button = "Tell the admin"
    @Environment(AppModel.self) private var model
    @State private var note = ""
    @State private var sending = false
    @State private var sent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            TextField("What did you see?", text: $note, axis: .vertical)
                .lineLimit(2...5).font(.system(size: 14))
                .padding(10)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack {
                Spacer()
                if sent {
                    Text("Sent to the admin.").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.done)
                } else {
                    Button { Task { await send() } } label: { Label(button, systemImage: "paperplane") }
                        .buttonStyle(.discover(.subtle))
                        .disabled(sending)
                }
            }
        }
    }

    private func send() async {
        guard let client = model.client else { return }
        sending = true
        defer { sending = false }
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await client.askAdmin(issueId: issueId, reportId: reportId, note: text.isEmpty ? nil : text)
            note = ""
            sent = true
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not send", variant: .error)
        }
    }
}

/// "Didn't help?" on a resolved report: reopens it and fusionha checks again.
struct IssueReopenButton: View {
    let issueId: Int
    let reportId: Int
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @State private var working = false
    @State private var reopened = false

    var body: some View {
        if reopened {
            Text("Reopened. We’re checking it again.").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
        } else {
            Button { Task { await reopen() } } label: { Label("Didn’t help?", systemImage: "arrow.uturn.backward") }
                .buttonStyle(.discover(.subtle))
                .disabled(working)
        }
    }

    private func reopen() async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            try await client.reopenIssue(id: issueId, reportId: reportId)
            reopened = true
            onDone()
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not reopen", variant: .error)
        }
    }
}
