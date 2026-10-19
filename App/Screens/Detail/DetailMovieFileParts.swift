import SwiftUI
import FusionhaKit

/// Which movie file "Edit movie file" opens.
struct MovieFileEditTarget: Identifiable {
    let versionId: Int
    let fileId: Int
    var id: Int { fileId }
}

/// "Edit movie file" (EditMovieFileDialog.tsx): the Manage files edit sheet on
/// this one file. Loads the version's managed rows, then edits the match and
/// reloads the page when something changed.
struct MovieFileEditSheet: View {
    @Environment(DetailStore.self) private var store
    @State private var model: ManageFilesModel
    let target: MovieFileEditTarget

    init(detail: ItemDetail, target: MovieFileEditTarget) {
        self.target = target
        _model = State(initialValue: ManageFilesModel(detail: detail, scopeVersionIds: [target.versionId], season: nil))
    }

    var body: some View {
        Group {
            if let item = model.items.first(where: { $0.id == target.fileId }) {
                ManageFileEditSheet(model: model, targets: [item])
            } else if model.loaded {
                NavigationStack {
                    EmptyBox(message: model.loadFailed ? "Couldn't load this file." : "This file is no longer registered.")
                        .padding(16)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(Theme.panel)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.panel)
            }
        }
        .task {
            model.client = store.client
            await model.load()
        }
        .onDisappear {
            if model.changed { Task { await store.reload() } }
        }
    }
}

/// The wanted card's download pill (DownloadPill.tsx): "downloading ▾" in the
/// grab wash; a tap pops the release, its client and indexer, the progress and
/// a link to the Queue.
struct DetailDownloadPill: View {
    @Environment(AppModel.self) private var model
    let edition: DetailEdition
    @State private var open = false

    private var label: String { edition.downloadState == "upgrading" ? "upgrading" : "downloading" }

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 6) {
                DetailSpinner(size: 11, color: Theme.grab, period: 0.9)
                Text(label)
                if let p = edition.progress, p > 0 { Text(verbatim: "\(Int(p.rounded()))%").monospacedDigit() }
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.grab)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .actWash(Theme.grab, mono: .grab, radius: 14)
            .contentShape(Capsule())
        }
        .buttonStyle(DetailPressStyle())
        .accessibilityLabel("\(edition.label) \(label)")
        .popover(isPresented: $open) {
            popover.presentationCompactAdaptation(.popover)
        }
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let release = edition.releaseTitle {
                Text(release)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                ForEach([edition.client, edition.indexer].compactMap { $0 }, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.txt.opacity(0.06), in: Capsule())
                }
            }
            if let p = edition.progress {
                ProgressView(value: min(max(p, 0), 100), total: 100).tint(Theme.grab)
            }
            Button {
                open = false
                model.tab = .activity
                model.presentedItem = nil
            } label: {
                Label("Open in Queue", systemImage: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 292, alignment: .leading)
    }
}
