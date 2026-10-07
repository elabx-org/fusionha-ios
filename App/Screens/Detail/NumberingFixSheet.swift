import SwiftUI
import FusionhaKit

/// "Fix episode numbering" (NumberingFixDialog.tsx): the whole-series preview
/// (`GET /api/v1/library/{id}/numbering/preview`) as season-by-season changes,
/// the re-link / unparseable / phantom summary, an explicit confirm, then
/// `POST …/numbering/apply` with the preview's hash, polled to completion.
struct NumberingFixSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail

    @State private var preview: NumberingPreview?
    @State private var loadError: String?
    @State private var confirmed = false
    @State private var applying = false
    /// The apply POST's refusal; a 409 (stale hash, or a download started) offers a re-preview.
    @State private var applyError: (message: String, recoverable: Bool)?

    private var isAdmin: Bool { model.me?.can("edit") ?? true }
    private var blocked: Bool { preview?.activeQueueBlocked == true }
    private var canApply: Bool { isAdmin && preview != nil && !blocked && confirmed && !applying }
    private var sourceLabel: String {
        NumberingCopy.sourceLabel(preview?.source ?? NumberingCopy.sourceGuess(provider: detail.metadataProvider))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DialogHeading(symbol: "tablecells", title: "Fix episode numbering",
                                  subtitle: "\(detail.title) · Comparing against \(sourceLabel) — whole series")
                    content
                }
                .padding(16)
            }
            .background(Theme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(applying ? "Applying…" : "Confirm & apply") { Task { await apply() } }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.indigo)
                        .disabled(!canApply)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            DialogBanner(text: loadError, tint: Theme.danger)
            Button("Try again") { Task { await load() } }.buttonStyle(.glass)
        } else if let preview {
            if blocked {
                DialogBanner(text: "Downloads are currently in flight for this series — wait for the queue to drain and try again.")
            }
            if !isAdmin {
                DialogBanner(text: "Only an admin can apply this fix. You can still review the changes below.", tint: Theme.cyan)
            }
            NumberingDiffList(preview: preview, sourceLabel: sourceLabel)
            if let applyError {
                DialogBanner(text: applyError.message, tint: Theme.danger)
                if applyError.recoverable {
                    Button("Refresh preview") { Task { await load() } }.buttonStyle(.glass)
                }
            }
            if isAdmin && !blocked {
                Toggle(isOn: $confirmed) {
                    Text("I understand this renumbers episodes and re-links files in place (no re-download, no files deleted).")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.txt)
                }
                .tint(Theme.indigo)
                .padding(.top, 4)
            }
        } else {
            DialogNote("Building the numbering preview…")
        }
    }

    private func load() async {
        guard let client = store.client else { return }
        applyError = nil
        confirmed = false
        do {
            preview = try await client.numberingPreview(itemId: detail.id)
            loadError = nil
        } catch {
            loadError = (error as? APIError)?.serverMessage ?? "Couldn't build the numbering preview."
        }
    }

    private func apply() async {
        guard let client = store.client, let preview, let hash = preview.diffHash else { return }
        applying = true
        defer { applying = false }
        do {
            let dispatch = try await client.applyNumbering(itemId: detail.id, source: preview.source, expectedHash: hash)
            let run = await store.waitForRun(dispatch.runId)
            await store.reload()
            if run?.status == "completed" {
                let summary = NumberingCopy.summary(run?.numberingSummary, itemTitle: detail.title)
                store.show(summary.message, title: summary.title, variant: summary.tone.toastVariant)
                dismiss()
            } else {
                store.show("Couldn't apply the numbering fix for \(detail.title) — see Activity for details.", variant: .error)
            }
        } catch let failure as APIError {
            if case .http(409, _) = failure {
                applyError = (message: failure.serverMessage, recoverable: true)
            } else {
                applyError = (message: failure.serverMessage, recoverable: false)
            }
        } catch {
            applyError = (message: "Couldn't apply the numbering fix.", recoverable: false)
        }
    }
}

private extension NumberingCopy.Tone {
    var toastVariant: DetailToast.Variant {
        switch self {
        case .success: return .success
        case .info: return .info
        case .warning: return .warning
        }
    }
}
