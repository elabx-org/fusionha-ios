import SwiftUI
import FusionhaKit

/// The commit bar pinned to the thumb zone: what the accepted rows adopt in
/// place, the per-tier file counts, Close and Import.
struct ImportCommitBar: View {
    let model: ImportWorkspaceModel
    let onClose: () -> Void

    var body: some View {
        let preview = model.session?.preview
        let titles = preview?.titles ?? 0
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LibraryImportRules.previewLine(preview))
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                    .lineLimit(2).minimumScaleFactor(0.85)
                HStack(spacing: 8) {
                    ForEach(LibraryImportRules.previewTiers(preview), id: \.self) { t in
                        HStack(spacing: 4) {
                            TierPill(tier: t.tier)
                            Text(LibraryImportRules.grouped(t.files))
                                .font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.mut)
                        }
                    }
                }
            }
            Spacer(minLength: 6)
            Button("Close", action: onClose).buttonStyle(.web())
            if model.isDraft {
                Button(model.working ? "Importing…" : "Import") { Task { await model.commit() } }
                    .buttonStyle(.web(.primary))
                    .disabled(titles == 0 || model.working)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}

/// While the backgrounded commit adopts files: a determinate bar from
/// `commit_done / commit_total`. Closing is safe; it keeps going.
struct ImportCommitProgressView: View {
    let session: LibraryImportSession
    let onClose: () -> Void

    var body: some View {
        let total = session.commitTotal ?? 0
        let done = session.commitDone ?? 0
        let pct = total > 0 ? min(100, Int((Double(done) / Double(total) * 100).rounded())) : 0
        let stalled = session.commitStalled == true
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Adopting files in place").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer()
                Text(total > 0 ? "\(LibraryImportRules.grouped(done)) of \(LibraryImportRules.grouped(total)) · \(pct)%" : "Starting…")
                    .font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.mut)
            }
            if total > 0 {
                ProgressView(value: Double(pct), total: 100).tint(stalled ? Theme.miss : Theme.i1)
            } else {
                ProgressView().controlSize(.small)
            }
            Text(stalled
                 ? "Stalled — the mount may be unresponsive. Your files on disk are untouched."
                 : "Runs in the background — you can close this and it keeps going. Media info (HDR / Atmos / codec) fills in after.")
                .font(.system(size: 13)).foregroundStyle(stalled ? Theme.miss : Theme.mut)
            HStack {
                Spacer()
                Button("Close", action: onClose).buttonStyle(.web())
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }
}

/// A commit the runner could not finish. Files on disk are untouched.
struct ImportCommitFailedView: View {
    let error: String?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Import failed", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.danger)
            Text(error ?? "Something went wrong while adopting files. Your files on disk are untouched — you can retry the import.")
                .font(.system(size: 13)).foregroundStyle(Theme.mut)
            HStack {
                Spacer()
                Button("Close", action: onClose).buttonStyle(.web())
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }
}
