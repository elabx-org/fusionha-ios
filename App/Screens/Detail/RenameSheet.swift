import SwiftUI
import FusionhaKit

/// "Preview rename" (RenamePanel.tsx): the `current → proposed` preview from
/// `GET /api/v1/library/{id}/rename?include_blocked=1`, the files fusionha
/// refuses to move in their own section, and "Rename N files"
/// (`POST /api/v1/library/{id}/rename`, scoped like the preview).
struct RenameSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let title: String
    let scope: RenameScope

    @State private var rows: [RenamePreviewRow]?
    @State private var failed = false
    @State private var applying = false

    private var split: (movable: [RenamePreviewRow], blocked: [RenamePreviewRow]) { RenameCopy.split(rows ?? []) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DialogHeading(symbol: "pencil", title: "Rename files",
                                  subtitle: "\(title) · organise \(RenameCopy.scopeText(versionId: scope.versionId, season: scope.season)) to the naming scheme")
                    content
                }
                .padding(16)
            }
            .background(Theme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await apply() } } label: {
                        ToolbarActionLabel(title: RenameCopy.applyLabel(count: split.movable.count), systemImage: "textformat")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.indigo)
                    .disabled(split.movable.isEmpty || applying)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if failed {
            DialogNote("Could not build the rename preview.")
        } else if rows == nil {
            DialogNote("Building preview…")
        } else if split.movable.isEmpty && split.blocked.isEmpty {
            DialogEmpty("Every file already matches the naming scheme.")
        } else {
            ForEach(split.movable) { row in
                RenameRowCard(row: row, toTag: "Proposed", reason: nil)
            }
            if !split.blocked.isEmpty {
                Text(RenameCopy.blockedHeading(split.blocked.count))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.miss)
                    .padding(.top, 8)
                Text("fusionha never overwrites a file it owns, so these are left where they are.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                ForEach(split.blocked) { row in
                    RenameRowCard(row: row, toTag: "Wanted", reason: RenameCopy.blockReason(row))
                }
            }
        }
    }

    private func load() async {
        guard let client = store.client else { return }
        do {
            rows = try await client.renamePreview(itemId: store.itemId, versionId: scope.versionId, season: scope.season)
        } catch {
            failed = true
        }
    }

    private func apply() async {
        guard let client = store.client, !split.movable.isEmpty else { return }
        applying = true
        defer { applying = false }
        do {
            let result = try await client.applyRename(itemId: store.itemId, versionId: scope.versionId, season: scope.season)
            let toast = RenameCopy.appliedToast(result)
            store.show(toast.message, variant: toast.isWarning ? .warning : .success)
            dismiss()
            await store.reload()
        } catch {
            store.show("Couldn't rename the files", variant: .error)
        }
    }
}

/// One `Current → Proposed` (or blocked `Current → Wanted` + reason) row.
private struct RenameRowCard: View {
    let row: RenamePreviewRow
    let toTag: String
    let reason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            line("Current", row.from, tint: Theme.mut, pathColor: Theme.mut)
            line(toTag, row.to, tint: reason == nil ? Theme.done : Theme.miss, pathColor: Theme.txt)
            if let reason {
                Text(reason)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.miss)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(reason == nil ? Theme.line : Theme.miss.opacity(0.35)))
    }

    private func line(_ tag: String, _ path: String, tint: Color, pathColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tag.uppercased())
                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(tint)
            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(pathColor)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
