import SwiftUI
import FusionhaKit

/// The per-import analyses nested under Media enrichment (web `EnrichmentTask`
/// `.more` toggle + `EnrichmentSubtaskRow`): "N import analyses", opening to
/// one row each with the same Pause / Cancel / Resume / Dismiss as the import card.
struct EnrichmentSubtasksView: View {
    let subtasks: [EnrichmentSubtask]
    let onChanged: () async -> Void
    @Environment(\.actReduceMotion) private var reduce
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button {
                if reduce { expanded.toggle() } else { withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() } }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Text("\(subtasks.count) import \(subtasks.count == 1 ? "analysis" : "analyses")")
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.dim)
                .padding(.leading, 16)
                .padding(.trailing, 14)
                .padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(expanded ? .isSelected : [])
            if expanded {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(subtasks.enumerated()), id: \.offset) { _, sub in
                        EnrichmentSubtaskRow(sub: sub, onChanged: onChanged)
                    }
                }
                .padding(.leading, 16)
                .transition(reduce ? .identity : .opacity.combined(with: .offset(y: -4)))
            }
        }
    }
}

private struct EnrichmentSubtaskRow: View {
    let sub: EnrichmentSubtask
    let onChanged: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @State private var busy = false

    var body: some View {
        let view = LibraryImportTaskView(sub)
        HStack(alignment: .center, spacing: 13) {
            TaskIconTile(color: Theme.grab) { Image(systemName: taskIcon(.refresh)) }
            VStack(alignment: .leading, spacing: 2) {
                (Text(sub.label ?? "Import").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                 + Text(" · \(view.stateLabel)").font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundColor(Theme.mut))
                    .lineLimit(2)
                Text(view.progressLabel).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let id = sub.importSessionId { controls(id, view) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(TaskCard())
        .disabled(busy)
    }

    @ViewBuilder
    private func controls(_ id: Int, _ view: LibraryImportTaskView) -> some View {
        if view.canPause {
            Menu {
                Button("Pause", systemImage: "pause") { act(id, .pause) }
                Button("Cancel", systemImage: "xmark", role: .destructive) { act(id, .cancel) }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut)
                    .frame(width: 32, height: 32).contentShape(Rectangle())
            }
            .accessibilityLabel("Controls for \(sub.label ?? "this import")")
        } else if view.canResume {
            HStack(spacing: 6) {
                Button("Dismiss") { act(id, .dismiss) }.buttonStyle(ActButtonStyle(kind: .ghost))
                Button("Resume") { act(id, .resume) }.buttonStyle(ActButtonStyle(kind: .primary))
            }
        }
    }

    private func act(_ id: Int, _ action: LibraryImportEnrichmentAction) {
        Task {
            busy = true
            defer { busy = false }
            do {
                try await model.client?.libraryImportEnrichment(id: id, action)
                await onChanged()
            } catch {
                toaster.error(error)
            }
        }
    }
}
