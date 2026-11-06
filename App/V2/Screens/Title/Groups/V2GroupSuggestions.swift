import SwiftUI
import FusionhaKit

/// "Seen on this title": the release groups of its files, history and
/// search results (`DetailStore.seenReleaseGroups`), one glass chip each,
/// the most seen first, never one already blocked here; narrowed to what
/// is typed. A tap fills the field.
struct V2GroupSuggestions: View {
    @Environment(DetailStore.self) private var store
    let typed: String
    let pick: (String) -> Void

    var body: some View {
        let groups = TitleGroupBlocks.suggestions(seen: store.seenReleaseGroups, blocks: store.groupBlocks ?? [],
                                                  itemId: store.itemId, typed: typed)
        let exact = groups.count == 1 && TitleGroupBlocks.key(groups[0]) == TitleGroupBlocks.key(typed)
        if !groups.isEmpty && !exact {
            VStack(alignment: .leading, spacing: 6) {
                Text("Seen on this title")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                GlassEffectContainer(spacing: 6) {
                    FlowRow(spacing: 6, lineSpacing: 6) {
                        ForEach(groups, id: \.self) { chip($0) }
                    }
                }
            }
        }
    }

    private func chip(_ group: String) -> some View {
        Button { pick(group) } label: {
            Text(group)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .accessibilityHint("Fills in the group name")
    }
}
