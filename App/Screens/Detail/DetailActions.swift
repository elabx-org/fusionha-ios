import SwiftUI
import FusionhaKit

/// The item actions rail (HeroActionRail): refresh split-button, rename,
/// manage, report, numbering, aliases, edit and delete in a glass capsule.
/// The rarely used dialogs (rename, manage, report, aliases, numbering fix)
/// open the same item in the web app.
struct ItemActionsRail: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let openWeb: () -> Void

    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var canDelete: Bool { model.me?.can("delete") ?? true }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                if canEdit {
                    refreshSplit
                    DetailRailButton(systemImage: "textformat", label: "Preview rename", action: openWeb)
                    DetailRailButton(systemImage: detail.isSeries ? "tablecells" : "folder.badge.plus",
                                   label: detail.isSeries ? "Manage episodes" : "Manage files", action: openWeb)
                }
                DetailRailButton(systemImage: "flag", label: "Report an issue", action: openWeb)
                if canEdit {
                    if detail.isSeries {
                        let mismatch = detail.numberingMismatch == true
                        DetailRailButton(systemImage: "list.number",
                                       label: mismatch ? "Review episode numbering" : "Check episode numbering",
                                       tint: mismatch ? Theme.miss : Theme.mut) {
                            Task { await store.checkNumbering(openWeb: openWeb) }
                        }
                    }
                    if detail.hasVersions {
                        DetailRailButton(systemImage: "tag", label: "Edition aliases", action: openWeb)
                    }
                    DetailRailButton(systemImage: "pencil", label: "Edit & monitoring") { store.showingEdit = true }
                }
                if canDelete {
                    DetailRailButton(systemImage: "trash", label: detail.isSeries ? "Delete series" : "Delete movie") {
                        store.showingDelete = true
                    }
                }
            }
            .padding(5)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    /// Main tap = metadata-only refresh; the caret offers the full rescan.
    private var refreshSplit: some View {
        HStack(spacing: 0) {
            DetailRailButton(systemImage: "arrow.clockwise", label: "Refresh metadata", busy: store.refreshing) {
                Task { await store.refresh(metadataOnly: true) }
            }
            Menu {
                Button {
                    Task { await store.refresh(metadataOnly: true) }
                } label: {
                    Label {
                        Text("Refresh metadata")
                        Text("Re-fetch TMDB/TVDB · fast · no file probe")
                    } icon: { Image(systemName: "arrow.clockwise") }
                }
                Button {
                    Task { await store.refresh(metadataOnly: false) }
                } label: {
                    Label {
                        Text("Refresh & scan files")
                        Text("Also re-probe every file on disk · slower")
                    } icon: { Image(systemName: "externaldrive.badge.checkmark") }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                    .frame(width: 22, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(store.refreshing)
            .accessibilityLabel("Refresh options")
        }
    }
}
