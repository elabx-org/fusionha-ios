import SwiftUI
import FusionhaKit

/// The confirmations behind the manager's file actions (web `StagedDialogs`,
/// `SwapRefusal`, `RegrabDialog`, `ResolveDialog`). Use / Discard send the
/// snapshot the dialog opened with, so a copy that changed underneath is
/// refused (`staged_changed`) rather than swapped unseen.
struct StagedDialogSheet: View {
    let issueId: Int
    let route: StagedDialogRoute
    let onSwitch: (StagedDialogRoute) -> Void
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var snap: IssueStagedCopy?
    @State private var working = false
    @State private var error: (text: String, code: String?, reason: String?)?
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) { content }.padding(16)
            }
            .background(Theme.panel)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .presentationDetents([.medium, .large])
        .onAppear { if snap == nil { snap = route.report?.stagedCopy } }
    }

    private var refused: Bool { error?.code == "swap_refused" || error?.code == "swap_restore_refused" }
    private var stale: Bool { error?.code.map { StagedFacts.staleCodes.contains($0) } ?? false }

    private var title: String {
        if refused {
            if error?.code == "swap_restore_refused" { return "The current copy couldn’t be put back" }
            return error?.reason == "swap_would_overwrite" ? "Held for you · both copies kept" : "The new copy couldn’t be swapped in"
        }
        switch route.kind {
        case .use: return "Use the new copy?"
        case .discard: return snap?.stuck != nil ? "Discard the stuck new copy?" : "Discard the new copy?"
        case .regrab: return "Re-grab this copy?"
        case .resolve: return "Resolve issue"
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if refused {
            refusal
        } else {
            switch route.kind {
            case .use, .discard: stagedBody
            case .regrab: regrabBody
            case .resolve: resolveBody
            }
            if let error, !(route.kind == .discard && error.code == "staged_stuck") {
                Text(error.text).font(.system(size: 13)).foregroundStyle(Theme.danger)
            }
            if route.kind == .discard, error?.code == "staged_stuck", let stuck = snap?.stuck {
                note("exclamationmark.triangle", Theme.miss, "Still stuck: \(StagedFacts.stuckWhy(stuck))",
                     (stuck.reason == "no_root" ? "Restore the version’s root folder, then discard it again. " : "Try again in a moment. ")
                     + "Nothing was removed and nothing was recorded as discarded.")
            }
        }
    }

    @ViewBuilder
    private var stagedBody: some View {
        if let snap {
            Text(route.kind == .use
                 ? "The new copy moves into place first, then the old one is removed and recorded in History."
                 : "The set-aside file is removed and recorded. The report goes back to you to resolve or re-grab.")
                .font(.system(size: 13)).foregroundStyle(Theme.mut)
            if route.kind == .use {
                copyCard("Removed: current copy", "trash", Theme.danger, snap.old)
                copyCard("Goes in: new copy", "checkmark", Theme.done, snap.new)
                Text("fusionha checks the new copy once more before it moves anything; if that check fails or the copies changed, nothing is swapped and both copies are kept. Then the new copy moves into place, the old one is removed and recorded in History, and \(route.report?.reporter?.displayName ?? "the reporter") is told it’s done. This can’t be undone from here.")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            } else {
                copyCard("Stays: current copy", "lock.fill", Theme.done, snap.old)
                copyCard("Removed: new copy", "trash", Theme.danger, snap.new)
            }
        }
    }

    private func copyCard(_ heading: String, _ symbol: String, _ tint: Color, _ copy: IssueCopyFacts?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(heading, systemImage: symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
            if let copy {
                Text(StagedFacts.qualitySize(copy)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                Text("Audio: \(StagedFacts.list(copy.audioLanguages))").font(.system(size: 12)).foregroundStyle(Theme.mut)
                Text("Check: \(StagedFacts.checkSentence(copy))").font(.system(size: 12)).foregroundStyle(Theme.mut)
                Text(StagedFacts.shortRelease(copy)).font(.system(size: 11).monospaced()).foregroundStyle(Theme.dim)
            } else {
                Text("No longer in the library").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .actWash(tint, radius: 12, base: Theme.card)
    }

    private var regrabBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A keep-old replacement for this version only.").font(.system(size: 13)).foregroundStyle(Theme.mut)
            note("lock.fill", Theme.done, "Kept until the new one checks out",
                 "The current copy stays in the library until the new one has downloaded and passed its check.")
            note("magnifyingglass", Theme.grab, "What happens",
                 "fusionha searches this version only, downloads the best release, sets it aside and checks it. If it plays, it replaces the current copy; your choice here is the confirmation.")
            Text("The release you have now isn’t blocked when decypharr says it plays. Grabs show as “Auto-fix” in History.")
                .font(.system(size: 12)).foregroundStyle(Theme.dim)
        }
    }

    private var resolveBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("An optional note for the reporter’s record.").font(.system(size: 13)).foregroundStyle(Theme.mut)
            TextField("Comment (optional)", text: $comment, axis: .vertical)
                .lineLimit(2...5)
                .padding(10)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @ViewBuilder
    private var refusal: some View {
        let restore = error?.code == "swap_restore_refused"
        let held = !restore && error?.reason == "swap_would_overwrite"
        Text("Nothing was lost: the thread records this for managers.").font(.system(size: 13)).foregroundStyle(Theme.mut)
        if held {
            note("checkmark.shield", Theme.mut, "fusionha won’t overwrite a copy that plays",
                 "The new copy would take the current copy’s file name, and the current copy still plays. With no recycle bin set there is nowhere to keep the old file, so the swap was not attempted. Nothing changed on disk.")
            Text("Set a recycle bin in Settings › Media and choose Use new copy again, or discard the new copy. A copy proven dead is replaced in place as usual; this only protects a playable one.")
                .font(.system(size: 12)).foregroundStyle(Theme.dim)
        } else {
            note("exclamationmark.triangle", Theme.miss, restore ? "The current copy is kept safely" : "Both copies are kept", error?.text ?? "")
        }
        if !restore && !held {
            Text("WHY USE NEW COPY CAN BE REFUSED").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(Theme.dim)
            ForEach(StagedFacts.refusalReasons.indices, id: \.self) { i in
                let r = StagedFacts.refusalReasons[i]
                let on = error?.reason.map { r.reasons.contains($0) } ?? false
                Label(r.text, systemImage: on ? "arrowtriangle.right.fill" : "circle.fill")
                    .font(.system(size: 12.5, weight: on ? .bold : .regular))
                    .foregroundStyle(on ? Theme.txt : Theme.mut)
                    .labelStyle(.titleAndIcon)
            }
        }
        if restore {
            Text("Discarding again would hit the same refusal, so it isn’t offered. Close this and open the thread: it records what happened, and an admin can restore the file’s folder or resolve the report from there.")
                .font(.system(size: 12)).foregroundStyle(Theme.dim)
        }
    }

    private func note(_ symbol: String, _ tint: Color, _ heading: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(heading).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .actWash(tint, radius: 12, base: Theme.card)
    }

    // MARK: Toolbar and actions

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(stale || refused ? "Close" : "Cancel") { dismiss() }
        }
        if refused {
            if error?.code != "swap_restore_refused", let report = route.report {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Discard new copy", role: .destructive) { onSwitch(StagedDialogRoute(kind: .discard, report: report)) }
                }
            }
        } else if !stale {
            ToolbarItem(placement: .confirmationAction) {
                Button { Task { await submit() } } label: { Text(working ? busyLabel : goLabel) }
                    .buttonStyle(.glassProminent)
                    .tint(route.kind == .discard ? Theme.danger : (route.kind == .use || route.kind == .resolve ? Theme.done : Theme.grab))
                    .disabled(working || ((route.kind == .use || route.kind == .discard) && snap == nil))
            }
        }
    }

    private var goLabel: String {
        switch route.kind {
        case .use: return "Use new copy"
        case .discard: return "Discard new copy"
        case .regrab: return "Re-grab"
        case .resolve: return "Resolve"
        }
    }

    private var busyLabel: String {
        switch route.kind {
        case .use: return "Swapping…"
        case .discard: return "Discarding…"
        case .regrab: return "Starting…"
        case .resolve: return "Resolving…"
        }
    }

    private func submit() async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            switch route.kind {
            case .use, .discard:
                guard let snap, let report = route.report else { return }
                try await client.stagedAction(issueId: issueId, reportId: report.id, use: route.kind == .use,
                                              oldFileId: snap.old?.fileId, stagedFileId: snap.new.fileId)
                model.toast(route.kind == .use ? "New copy in place" : "New copy discarded")
            case .regrab:
                guard let report = route.report else { return }
                try await client.issueAction(issueId: issueId, reportId: report.id, action: "regrab")
                model.toast("Re-grab started")
            case .resolve:
                let note = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                try await client.resolveIssue(id: issueId, comment: note.isEmpty ? nil : note)
                model.toast("Issue resolved")
            }
            onDone()
            dismiss()
        } catch {
            let api = error as? APIError
            self.error = (ErrorCopy.message(for: error), api?.code, api?.reason)
            if stale { onDone() }
        }
    }
}
