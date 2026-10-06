import SwiftUI
import FusionhaKit

/// The item actions rail (HeroActionRail at ≤720px): a glass pill of icon
/// buttons in the web's order — Refresh (split: tap = metadata only, caret =
/// menu), Preview rename, Manage files / episodes, Report an issue, Check
/// episode numbering (series), Edition aliases (a title with a non-Standard
/// edition), Edit & monitoring, Delete. Like the web it wraps to a second row
/// rather than scrolling an action out of sight. A user without `edit` keeps
/// only Report an issue and the numbering check, as on the web.
struct ItemActionsRail: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let openWeb: () -> Void

    private var canEdit: Bool { model.me?.can("edit") ?? true }

    private var actions: [ItemAction] {
        ItemAction.rail(isSeries: detail.isSeries, canEdit: canEdit, hasNonStandardEdition: detail.hasVersions)
    }

    var body: some View {
        FlowRow(spacing: 4) {
            ForEach(actions, id: \.self) { action in
                if action == .refresh {
                    RefreshSplitButton()
                } else {
                    button(action)
                }
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    private func button(_ action: ItemAction) -> some View {
        let flagged = detail.numberingMismatch == true
        return DetailRailButton(systemImage: Self.symbol(action), label: action.label(isSeries: detail.isSeries, numberingFlagged: flagged),
                                glyph: 17, tint: action == .checkNumbering && flagged ? Theme.miss : Theme.mut,
                                busy: action == .checkNumbering && store.checkingNumbering) {
            perform(action)
        }
    }

    private func perform(_ action: ItemAction) {
        switch action {
        case .refresh: Task { await store.refresh(metadataOnly: true) }
        case .previewRename: store.openRename()
        // ManageExistingFilesDialog / ManageEpisodesDialog are not ported yet.
        case .manageFiles, .manageEpisodes: openWeb()
        case .reportIssue: store.showingIssue = true
        case .checkNumbering: Task { await store.checkNumbering() }
        case .editionAliases: store.showingAliases = true
        case .edit: store.showingEdit = true
        case .delete: store.showingDelete = true
        }
    }

    /// The web's rail glyphs as SF Symbols (CLAUDE.md: edit = pencil, delete = trash, refresh = arrow.clockwise).
    static func symbol(_ action: ItemAction) -> String {
        switch action {
        case .refresh: return "arrow.clockwise"
        case .previewRename: return "textformat"
        case .manageEpisodes: return "tablecells"
        case .manageFiles: return "folder.badge.plus"
        case .reportIssue: return "flag"
        case .checkNumbering: return "list.number"
        case .editionAliases: return "tag"
        case .edit: return "pencil"
        case .delete: return "trash"
        }
    }
}

/// Split "Refresh": the main half is a one-tap metadata refresh; the caret
/// opens the menu offering both "Refresh metadata" and "Refresh & scan files".
/// Both halves disable while the refresh runs.
private struct RefreshSplitButton: View {
    @Environment(DetailStore.self) private var store

    var body: some View {
        HStack(spacing: 0) {
            DetailRailButton(systemImage: "arrow.clockwise", label: "Refresh metadata", glyph: 17, busy: store.refreshing) {
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
                    } icon: { Image(systemName: "list.bullet.rectangle") }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.dim)
                    .frame(width: 18, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(store.refreshing)
            .accessibilityLabel("Refresh options")
        }
    }
}
