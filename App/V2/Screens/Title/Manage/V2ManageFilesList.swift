import SwiftUI
import FusionhaKit

/// The Files tab: the scope line, the quick chips, any note, then one solid
/// card per season on the wash.
struct V2ManageFilesList: View {
    let model: ManageFilesModel
    let groups: [ManageSeasonGroup]
    @Binding var expanded: Set<Int>
    let actions: V2ManageActions
    @Environment(\.pagePalette) private var page

    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text(model.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(muted)
                    .lineLimit(2)
                    .padding(.horizontal, 20)
                if !groups.isEmpty {
                    V2ManageQuickChips(model: model, groups: groups)
                }
                if let note = model.note { noteLine(note).padding(.horizontal, 20) }
                content
            }
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable { await model.load() }
    }

    @ViewBuilder private var content: some View {
        if !model.loaded {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
        } else if model.loadFailed && model.items.isEmpty {
            message("Couldn’t load this title’s files. Try Re-scan.")
        } else if groups.isEmpty {
            message("No files under this title in this scope.")
        } else {
            ForEach(groups) { group in
                V2ManageSeasonCard(model: model, group: group,
                                   showsTierPerRow: group.tiers.count > 1,
                                   expanded: expandedBinding(group.season),
                                   actions: actions)
                    .padding(.horizontal, 16)
            }
            Text("Tap a file to see its name and edit it. Delete frees the space; Replace (hold a row) deletes and searches again.")
                .font(.system(size: 12))
                .foregroundStyle(muted)
                .padding(.horizontal, 20)
                .padding(.top, 4)
        }
    }

    private func expandedBinding(_ season: Int) -> Binding<Bool> {
        Binding(get: { expanded.contains(season) },
                set: { if $0 { expanded.insert(season) } else { expanded.remove(season) } })
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    private func noteLine(_ note: ManageFilesModel.Note) -> some View {
        Label(note.text, systemImage: note.failed ? "exclamationmark.circle" : "checkmark.circle")
            .font(.footnote.weight(.medium))
            .foregroundStyle(note.failed ? Theme.dangerText : (page?.ink ?? Theme.txt))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background { ModuleSurface(radius: 14) }
    }
}
