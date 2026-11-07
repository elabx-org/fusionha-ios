import SwiftUI
import FusionhaKit

/// A season card's header (mock frames 1–2): the tri-state circle,
/// "Season 1", "13 files · 32.4 GB", the facts the season's files share
/// (tier ticket, source + resolution, audio, group), the collapse chevron
/// and the ••• menu (select, re-check, change quality or group, delete).
struct V2ManageSeasonHeader: View {
    let model: ManageFilesModel
    let group: ManageSeasonGroup
    let expanded: Bool
    let actions: V2ManageActions
    let toggleExpanded: () -> Void
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var state: ManageSelectState { ManageEpisodes.state(group, selected: model.selected) }
    private var items: [ManagedFileItem] { group.lines.map(\.item) }
    private var countLine: String {
        "\(group.count == 1 ? "1 file" : "\(group.count) files") · \(DetailText.bytes(group.bytes))"
    }

    /// "Select season 1, 13 files, 32.4 gigabytes".
    private var circleLabel: String {
        let name = group.season > 0 ? "season \(group.season)" : group.title.lowercased()
        return "Select \(name), \(group.count == 1 ? "1 file" : "\(group.count) files"), \(V2ManageSpeech.size(group.bytes))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Button { model.selected = ManageEpisodes.toggling(group, in: model.selected) } label: {
                V2ManageSelectCircle(state: state)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .accessibilityLabel(circleLabel)
            .accessibilityValue(V2ManageSpeech.state(state))
            .accessibilityAddTraits(state == .all ? .isSelected : [])
            Button(action: toggleExpanded) { titleBlock }
                .buttonStyle(.plain)
                .accessibilityHint(expanded ? "Hides the episodes" : "Shows the episodes")
            menu
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
    }

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ink)
                Text(countLine)
                    .font(.system(size: 12.5))
                    .monospacedDigit()
                    .foregroundStyle(muted)
                FlowRow(spacing: 5, lineSpacing: 4) {
                    ForEach(group.tiers, id: \.self) { EditionBadge(tier: $0, state: .onDisk, showsCount: false) }
                    ForEach(group.shared) { V2ManageFactChip(fact: $0) }
                }
                .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(muted)
                .rotationEffect(.degrees(expanded ? 0 : -90))
                .frame(height: 22)
                .accessibilityHidden(true)
        }
        .padding(.top, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(group.title), \(countLine)")
        .accessibilityValue([group.tiers.map(\.badgeLetters).joined(separator: " "), V2ManageSpeech.facts(group.shared)]
            .filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }

    private var menu: some View {
        Menu {
            Button(state == .all ? "Deselect \(group.title)" : "Select \(group.title)", systemImage: "checkmark.circle") {
                model.selected = ManageEpisodes.toggling(group, in: model.selected)
            }
            if group.season >= 0 {
                Button { actions.recheck(group.season) } label: {
                    Label("Re-check files", systemImage: "arrow.clockwise")
                    Text("\(group.count)")
                }
                .disabled(model.rescanning)
            }
            Button("Change quality or group…", systemImage: "pencil") { actions.edit(items) }
            Divider()
            Button(role: .destructive) { actions.delete(items) } label: {
                Label("Delete season files…", systemImage: "trash")
                Text(DetailText.bytes(group.bytes))
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.interactive(), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .accessibilityLabel("\(group.title) actions")
        .disabled(model.busy || model.deleting != nil)
    }
}
