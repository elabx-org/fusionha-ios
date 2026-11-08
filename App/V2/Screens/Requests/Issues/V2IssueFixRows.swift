import SwiftUI
import FusionhaKit

/// "Choose a fix" on the reporter's v2 issue thread (look-pass mock
/// `issueThread`): one grouped card, a row per offered fix with its line
/// and its button on the right. The first fix the viewer can take is the
/// accent (the primary action); the rest are glass. A fix they can't take
/// stays, dimmed, with the reason. Same calls as v1's `IssueChoiceList`.
struct V2IssueFixRows: View {
    let issueId: Int
    let report: IssueReport
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @State private var started: String?
    @State private var done: Set<String> = []

    private var manager: Bool { model.me?.hasPermission("issues.manage") ?? false }
    private var primaryId: String? { report.choices.first { $0.allowed }?.id }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(report.choices.enumerated()), id: \.element.id) { index, c in
                if index > 0 { Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 16) }
                row(c)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous).strokeBorder(Theme.line))
        .clipShape(RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous))
    }

    private func row(_ c: IssueChoice) -> some View {
        let look = IssueFormat.choiceButton(c.id)
        let hint = c.allowed ? c.sub : IssueFormat.disabledSub(c.permission, manager: manager, choiceId: c.id, dailyLimit: c.dailyLimit)
        let label = started == c.id ? "Starting…" : (done.contains(c.id) ? look.done : look.text)
        let disabled = !c.allowed || started != nil || done.contains(c.id)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(c.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(c.allowed ? Theme.txt : Theme.mut)
                if let hint, !hint.isEmpty {
                    Text(hint).font(.system(size: 13.5)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            button(label, primary: c.id == primaryId) { Task { await run(c) } }
                .disabled(disabled)
                .accessibilityHint(c.allowed ? "" : IssueFormat.permissionHint(c.permission, manager: manager, choiceId: c.id, dailyLimit: c.dailyLimit))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(c.allowed ? 1 : 0.75)
    }

    @ViewBuilder
    private func button(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        if primary {
            Button(title, action: action).buttonStyle(.glassProminent).fixedSize()
        } else {
            Button(title, action: action).buttonStyle(.glass).fixedSize()
        }
    }

    private func run(_ c: IssueChoice) async {
        guard let client = model.client else { return }
        started = c.id
        defer { started = nil }
        do {
            _ = try await client.issueAction(issueId: issueId, reportId: report.id, action: c.id)
            done.insert(c.id)
            onChanged()
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not start that fix", variant: .error)
        }
    }
}

/// "Or tell the admin" as one row: the note field and its button (the same
/// ask-admin call as v1's `IssueReportBox`). Once sent it says so.
struct V2TellAdminRow: View {
    let issueId: Int
    let reportId: Int
    @Environment(AppModel.self) private var model
    @State private var note = ""
    @State private var sending = false
    @State private var sent = false

    var body: some View {
        HStack(spacing: 10) {
            if sent {
                Label("Sent to the admin.", systemImage: "checkmark")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
            } else {
                TextField("What did you see?", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 16))
                Button(sending ? "Sending…" : "Tell the admin") { Task { await send() } }
                    .buttonStyle(.glass)
                    .fixedSize()
                    .disabled(sending)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous).strokeBorder(Theme.line))
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

/// "Didn't help?" as a quiet accent link: reopens a resolved report and
/// fusionha checks it again (the same call as v1's `IssueReopenButton`).
struct V2DidntHelpLink: View {
    let issueId: Int
    let reportId: Int
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @State private var working = false
    @State private var reopened = false

    var body: some View {
        if reopened {
            Text("Reopened. We’re checking it again.").font(.system(size: 13)).foregroundStyle(Theme.mut)
        } else {
            Button { Task { await reopen() } } label: {
                Label("Didn’t help?", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
            }
            .buttonStyle(.plain)
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
