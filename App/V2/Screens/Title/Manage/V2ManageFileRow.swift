import SwiftUI
import FusionhaKit

/// One file in a season card (mock frame 1): the select circle, mono
/// "S01·E01" and the episode's title, its runtime (and health), any fact
/// that differs from the season's in orange, and the size on the right in
/// monospaced digits. The filename lives in the file sheet a tap opens.
struct V2ManageFileRow: View {
    let model: ManageFilesModel
    let line: ManageEpisodeLine
    /// The season holds more than one version's files.
    let showsTier: Bool
    let actions: V2ManageActions
    @Environment(\.pagePalette) private var page

    private var item: ManagedFileItem { line.item }
    private var selected: Bool { model.selected.contains(line.id) }
    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Button { model.toggle(line.id) } label: {
                V2ManageSelectCircle(state: selected ? .all : .none)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(line.code)")
            .accessibilityAddTraits(selected ? .isSelected : [])
            Button { actions.edit([item]) } label: { content }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the file and edits it")
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .padding(.vertical, 4)
        .contextMenu { menu }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if showsTier {
                        Text(item.row.tier.badgeLetters)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(muted)
                    }
                    Text(line.code)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ink)
                        .fixedSize()
                    if let title = line.title {
                        Text(title)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(item.extra ? muted : ink)
                            .lineLimit(1)
                    }
                }
                meta
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(DetailText.bytes(line.bytes))
                .font(.system(size: 13.5))
                .monospacedDigit()
                .foregroundStyle(ink)
                .fixedSize()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    @ViewBuilder private var meta: some View {
        let health = healthWords
        if line.minutes != nil || !line.chips.isEmpty || !health.isEmpty {
            FlowRow(spacing: 5, lineSpacing: 4) {
                if let m = line.minutes {
                    Text("\(m)m").font(.system(size: 12)).monospacedDigit().foregroundStyle(muted)
                }
                ForEach(line.chips) { V2ManageFactChip(fact: $0) }
                ForEach(health, id: \.self) { word in
                    Text(word)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(item.dead ? Theme.dangerText : muted)
                }
            }
        }
    }

    private var healthWords: [String] {
        var out: [String] = []
        if item.dead { out.append("Dead link") } else if item.unreadable { out.append("Unreadable") }
        if item.extra { out.append("Extra") }
        if !item.monitored { out.append("Unmonitored") }
        return out
    }

    private var spoken: String {
        var parts = [line.code, line.title, line.minutes.map { "\($0) minutes" }, V2ManageSpeech.size(line.bytes)]
            .compactMap { $0 }
        if !line.chips.isEmpty { parts.append(V2ManageSpeech.facts(line.chips)) }
        parts += healthWords
        return parts.joined(separator: ", ")
    }

    @ViewBuilder private var menu: some View {
        Button("Edit", systemImage: "pencil") { actions.edit([item]) }
        if item.monitored {
            Button(item.unreadable ? "Replace anyway" : "Replace", systemImage: "arrow.triangle.2.circlepath") {
                actions.confirm(.replace([item]))
            }
        } else {
            Button("Clean up dead link", systemImage: "link") { actions.confirm(.cleanup([item])) }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { actions.delete([item]) }
    }
}
