import SwiftUI
import FusionhaKit

struct MetadataSwitchTarget: Identifiable {
    let provider: String
    var id: String { provider }
}

/// "Switch metadata source" (MetadataSwitchDialog.tsx): Match (the target
/// series the provider resolved, or an id you type), Review (the numbering
/// plan and the file renames, each file can be left out), then apply with the
/// reviewed plan's hash and poll the run. Done offers Undo.
struct MetadataSwitchSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail
    let target: String

    enum Step { case match, review, done }
    @State private var step: Step = .match
    @State private var preview: MetadataSwitchPreview?
    @State private var plan: NumberingPlan?
    @State private var failure: String?
    @State private var manualId = ""
    @State private var excluded: Set<Int> = []
    @State private var committing = false
    @State private var undone = false
    @State private var loadGeneration = 0

    private var label: String { MetadataSwitchLogic.label(target) }
    private var isAdmin: Bool { model.me?.can("edit") ?? true }
    private var blocked: Bool { preview?.activeQueueBlocked == true || plan?.blockedByQueue == true }
    private var renameable: [MetadataSwitchFile] { (preview?.files ?? []).filter { $0.newName != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    DialogHeading(symbol: "arrow.left.arrow.right",
                                  title: step == .done ? "Switch complete" : "Switch metadata source · \(detail.title)",
                                  subtitle: step == .done ? "The source, numbering and filenames were updated together."
                                      : "\(MetadataSwitchLogic.label(MetadataSwitchLogic.current(detail.metadataProvider))) → \(label). Re-fetch the \(label) tree, review the plan, then apply.")
                    if let failure { DialogBanner(text: failure, tint: Theme.danger) }
                    switch step {
                    case .match: matchStep
                    case .review: MetadataSwitchReview(plan: plan, files: preview?.files ?? [], renameCount: preview?.renameCount ?? 0,
                                                       blocked: blocked, excluded: $excluded)
                    case .done: doneStep
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) { footer }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .interactiveDismissDisabled(committing)
        .task { await load(targetId: nil) }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCancelButton(title: step == .done ? "Close" : "Cancel") { dismiss() }
        }
        if step == .review {
            ToolbarItem(placement: .topBarLeading) { Button("Back", systemImage: "chevron.left") { step = .match } }
        }
    }

    @ViewBuilder
    private var matchStep: some View {
        if let preview {
            if let match = preview.matched {
                HStack(spacing: 12) {
                    Color.clear.frame(width: 46, height: 69)
                        .overlay { DiscoverArt(url: TMDBImage.resized(match.poster, to: "w342")) }
                        .shelfPoster(shadow: false)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(match.title ?? "#\(match.id)").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                        Text(verbatim: [match.year.map { "\($0)" }, "\(label) #\(match.id)"].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.mut)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .detailCard(radius: 14, shadow: false)
            } else if target != "hybrid" {
                DialogBanner(text: "Couldn't find this series on \(label). Enter its \(label) id below.")
            }
            let flagged = (preview.files ?? []).filter { $0.confidence == "title-only-warn" }.count
            VStack(alignment: .leading, spacing: 4) {
                if let plan { Text(MetadataSwitchLogic.summary(plan)) }
                Text("\(renameable.count) file\(renameable.count == 1 ? "" : "s") to rename" + (flagged > 0 ? " · \(flagged) flagged" : ""))
            }
            .font(.system(size: 13)).foregroundStyle(Theme.mut)
            if blocked { DialogBanner(text: "Downloads are in flight for this series — wait for the queue to drain.") }
            if target != "hybrid" && isAdmin {
                HStack {
                    TextField("Not the right show? \(label) id", text: $manualId)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    Button("Use") { Task { await load(targetId: Int(manualId)) } }
                        .buttonStyle(.glass)
                        .disabled(Int(manualId) == nil)
                }
            }
        } else if failure == nil {
            DialogNote("Matching on \(label)…")
        } else {
            Button("Try again", systemImage: "arrow.clockwise") { Task { await load(targetId: Int(manualId)) } }
                .buttonStyle(.glass)
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Switched to \(label)", systemImage: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.done)
            Text("\(detail.title) is now sourced from \(label). You can undo this — provider, numbering and filenames revert together.")
                .font(.system(size: 13)).foregroundStyle(Theme.mut)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 10) {
            switch step {
            case .match:
                Spacer()
                Button("Continue") { step = .review }
                    .buttonStyle(.glassProminent).tint(Theme.i1)
                    .disabled(preview?.matched == nil && target != "hybrid" || plan == nil)
            case .review:
                Text(MetadataSwitchLogic.why(plan, blocked: blocked)).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                Spacer(minLength: 4)
                Menu {
                    Button("Switch & rename \(renameable.count - excluded.count) files") { Task { await commit(rename: true) } }
                    Button("Switch only, keep filenames") { Task { await commit(rename: false) } }
                } label: {
                    Text(committing ? "Applying…" : "Apply")
                } primaryAction: { Task { await commit(rename: true) } }
                .buttonStyle(.glassProminent).tint(Theme.i1)
                .disabled(!isAdmin || blocked || committing || plan == nil)
            case .done:
                Spacer()
                Button(undone ? "Reverted" : "Undo switch") { Task { await undo() } }
                    .buttonStyle(.glass)
                    .disabled(undone || !isAdmin)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func load(targetId: Int?) async {
        guard let client = store.client else { return }
        // Only the newest load reports: an older one that ends later must not
        // overwrite its answer, and a load cancelled with its view says nothing.
        loadGeneration += 1
        let generation = loadGeneration
        failure = nil
        do {
            let p = try await client.metadataSwitchPreview(itemId: detail.id, target: target, targetId: targetId)
            let next = try await client.numberingPlan(itemId: detail.id, target: target, intent: "switch",
                                                      targetId: target == "hybrid" ? nil : p.matched?.id)
            guard generation == loadGeneration else { return }
            preview = p
            plan = next
            failure = nil
        } catch {
            if generation != loadGeneration || Task.isCancelled || error is CancellationError
                || (error as? URLError)?.code == .cancelled { return }
            failure = MetadataSwitchLogic.previewFailure(error)
        }
    }

    private func commit(rename: Bool) async {
        guard let client = store.client, let plan else { return }
        committing = true
        defer { committing = false }
        failure = nil
        do {
            let dispatch = try await client.metadataSwitchCommit(itemId: detail.id, MetadataSwitchCommitBody(
                targetProvider: target, targetId: target == "hybrid" ? nil : preview?.matched?.id,
                renameFiles: rename, excludeFileIds: excluded.sorted(), planHash: plan.planHash))
            var run: MetadataSwitchRun?
            for _ in 0..<200 {
                try? await Task.sleep(for: .seconds(1.5))
                if let r = try? await client.metadataSwitchRun(id: dispatch.runId), !r.isRunning { run = r; break }
            }
            await store.reload()
            if run?.status == "completed" {
                let renamed = run?.metadataSwitchSummary?.renamedFiles ?? 0
                store.show(renamed > 0 ? "Switched \(detail.title) to \(label) — \(renamed) file\(renamed == 1 ? "" : "s") renamed."
                                       : "Switched \(detail.title) to \(label).", variant: .success)
                step = .done
            } else {
                failure = "Couldn't switch \(detail.title) — see Activity for details."
            }
        } catch let error as APIError {
            if case .http(409, _) = error {
                failure = "The plan changed since you reviewed it. Review it again."
                self.plan = nil
                step = .match
                await load(targetId: preview?.matched?.id)
            } else {
                failure = error.serverMessage
            }
        } catch {
            failure = "Couldn't switch \(detail.title)."
        }
    }

    private func undo() async {
        guard let client = store.client else { return }
        do {
            _ = try await client.metadataSwitchUndo(itemId: detail.id)
            undone = true
            store.show("Reverted \(detail.title) to its previous metadata source.", variant: .success)
            await store.reload()
        } catch {
            failure = (error as? APIError)?.serverMessage ?? "Could not undo the switch."
        }
    }
}
