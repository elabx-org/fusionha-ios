import SwiftUI
import FusionhaKit

/// The full-screen Library import workspace (web `ImportWorkspaceModal`): the
/// session state, then one of the triage (Sources, Bulk, Needs you, Ready and
/// the commit bar), the commit progress, the report, or the failure.
struct ImportWorkspaceSheet: View {
    @State private var model: ImportWorkspaceModel
    @State private var confirmDiscard = false
    @State private var editing: ImportRowTarget?
    @State private var overriding: ImportRowTarget?
    /// Override picked from the editor: opened once the editor has gone.
    @State private var overrideNext: ImportRowTarget?
    @Environment(\.dismiss) private var dismiss

    init(sessionId: Int, client: APIClient?) {
        _model = State(initialValue: ImportWorkspaceModel(sessionId: sessionId, client: client))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Library import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .task { await model.run() }
        .onDisappear { Task { await model.flush() } }
        .confirmationDialog("Discard this draft?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                Task { if await model.discard() { dismiss() } }
            }
        } message: {
            Text("Files on disk are untouched.")
        }
        .alert("Library import", isPresented: errorShown) {
            Button("OK", role: .cancel) { model.actionError = nil }
        } message: {
            Text(model.actionError ?? "")
        }
        .sheet(item: $editing, onDismiss: {
            overriding = overrideNext
            overrideNext = nil
        }) { target in
            ImportRowEditorSheet(model: model, itemId: target.id) { overrideNext = ImportRowTarget(id: target.id) }
        }
        .sheet(item: $overriding) { target in
            ImportOverrideSheet(model: model, itemId: target.id)
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { model.actionError != nil }, set: { if !$0 { model.actionError = nil } })
    }

    @ViewBuilder
    private var content: some View {
        if let session = model.session {
            if session.isCommitting {
                ImportCommitProgressView(session: session) { dismiss() }
            } else if session.isCommitted, let result = session.commitResult {
                ImportReportView(result: result, model: model) { dismiss() }
            } else if session.isFailed {
                ImportCommitFailedView(error: session.commitResult?.error) { dismiss() }
            } else {
                ImportTriageList(model: model,
                                 onEdit: { editing = ImportRowTarget(id: $0) },
                                 onOverride: { overriding = ImportRowTarget(id: $0) },
                                 onClose: { dismiss() })
            }
        } else if let error = model.loadError {
            ContentUnavailableView("Couldn’t load this import", systemImage: "exclamationmark.triangle",
                                   description: Text(error))
        } else {
            ProgressView("Loading session…").frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCancelButton(title: "Close") { dismiss() }
        }
        // No ⋯ menu (D1): Rescan all is a system item, Discard goes to the
        // system overflow.
        if model.isDraft {
            ToolbarItem(placement: .primaryAction) {
                Button("Rescan all", systemImage: "arrow.clockwise") { Task { await model.rescan() } }
                    .disabled(model.working)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Discard", systemImage: "trash", role: .destructive) { confirmDiscard = true }
                    .disabled(model.working)
            }
        }
    }
}

/// A row the editor or override sheet is open on, by its `scan_id:folder_key`.
struct ImportRowTarget: Identifiable, Hashable {
    let id: String
}

/// The session bar's state line: Saving… → Draft · auto-saved HH:MM.
struct ImportSessionStateLine: View {
    let model: ImportWorkspaceModel

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
        }
    }

    private var color: Color {
        if model.isDraft, model.saveFailed { return Theme.danger }
        if model.isDraft, model.saving { return Theme.miss }
        return Theme.done
    }

    private var text: String {
        guard let session = model.session else { return "" }
        if !session.isDraft { return session.isCommitted ? "Imported" : "Discarded" }
        if model.saveFailed { return "Not saved — will retry" }
        if model.saving { return "Saving…" }
        let time = Format.timestamp(session.updatedAt).map { $0.formatted(date: .omitted, time: .shortened) }
        return "Draft · auto-saved" + (time.map { " \($0)" } ?? "")
    }
}
