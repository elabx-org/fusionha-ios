import SwiftUI
import FusionhaKit

/// The post-import analysis task for one committed import (web
/// `PostImportTaskCard`): the MediaInfo sweep over just that job's files.
/// Shown while it runs, is paused or cancelled, or left files it couldn't read.
/// Pause and Cancel while analysing, Resume once paused or cancelled.
struct ImportPostTaskCard: View {
    let sessionId: Int
    let enrichment: LibraryImportEnrichment
    let onChanged: () async -> Void
    @Environment(AppModel.self) private var model
    @State private var busy = false
    @State private var error: String?

    private var info: LibraryImportTaskView { LibraryImportTaskView(enrichment) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            Text(info.progressLabel).font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Theme.mut)
            ProgressView(value: Double(info.percent), total: 100)
                .tint(Theme.mut)
                .accessibilityLabel("Post-import analysis")
            issues
            controls
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
        }
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if info.isAnalyzing {
                ProgressView().controlSize(.mini)
            } else {
                Circle().fill(Theme.dim).frame(width: 7, height: 7)
            }
            Text("Post-import analysis").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
            Text(info.stateLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Theme.panel2, in: Capsule())
            Spacer(minLength: 4)
            if info.issueCount > 0 {
                Text("\(LibraryImportRules.grouped(info.issueCount)) need attention")
                    .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.miss)
            }
        }
    }

    @ViewBuilder
    private var issues: some View {
        let list = enrichment.issues ?? []
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(list) { issue in
                    HStack(alignment: .firstTextBaseline) {
                        Text(issue.title).font(.system(size: 12.5)).foregroundStyle(Theme.txt).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(LibraryImportTaskView.reasonLabel(issue.reason))
                            .font(.system(size: 11.5)).foregroundStyle(Theme.miss)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if info.canPause || info.canResume {
            HStack(spacing: 8) {
                if info.canPause {
                    Button("Pause") { run(.pause) }.buttonStyle(.web())
                    Button("Cancel") { run(.cancel) }.buttonStyle(.web())
                }
                if info.canResume {
                    Button("Resume") { run(.resume) }.buttonStyle(.web(.primary))
                }
                Spacer(minLength: 0)
            }
            .disabled(busy)
        }
    }

    private func run(_ action: LibraryImportEnrichmentAction) {
        guard let client = model.client else { return }
        busy = true
        Task {
            do {
                try await client.libraryImportEnrichment(id: sessionId, action)
                error = nil
                await onChanged()
            } catch {
                self.error = ErrorCopy.message(for: error, fallback: "Couldn’t update the analysis.")
            }
            busy = false
        }
    }
}
