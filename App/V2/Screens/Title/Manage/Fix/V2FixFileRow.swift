import SwiftUI
import FusionhaKit

/// One problem file in Fix mode (mock frames 1 and 3): the select circle
/// only when there is more than one, mono code and episode title with the
/// orange "!", runtime and facts, the reason in orange beneath, and the
/// size on the right. A movie's row names the file. Tap opens the editor.
struct V2FixFileRow: View {
    let model: ManageFilesModel
    let line: ManageEpisodeLine
    let selectable: Bool
    let edit: () -> Void
    @Environment(\.pagePalette) private var page

    private var item: ManagedFileItem { line.item }
    private var selected: Bool { model.selected.contains(line.id) }
    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var reason: String? { ManageFix.reason(item, clock: Self.clock) }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if selectable {
                Button { model.toggle(line.id) } label: {
                    V2ManageSelectCircle(state: selected ? .all : .none)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select \(heading)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Button(action: edit) { content }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the file and edits it")
        }
        .padding(.leading, selectable ? 4 : 16)
        .padding(.trailing, 16)
        .padding(.vertical, 4)
    }

    private var isEpisode: Bool { item.row.season != nil && !item.row.episodes.isEmpty }
    private var heading: String { isEpisode ? line.code : item.name }

    private var content: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if isEpisode {
                        Text(line.code)
                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ink)
                            .fixedSize()
                    }
                    Text(isEpisode ? (line.title ?? "") : item.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.stuck)
                        .accessibilityHidden(true)
                }
                meta
                if let reason {
                    Text(reason)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.stuckText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(DetailText.bytes(line.bytes))
                .font(.system(size: 13.5))
                .monospacedDigit()
                .foregroundStyle(ink)
                .fixedSize()
                .padding(.top, 1)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    @ViewBuilder private var meta: some View {
        if line.minutes != nil || !line.chips.isEmpty {
            FlowRow(spacing: 5, lineSpacing: 4) {
                if let m = line.minutes {
                    Text("\(m)m").font(.system(size: 12)).monospacedDigit().foregroundStyle(muted)
                }
                ForEach(line.chips) { V2ManageFactChip(fact: $0) }
            }
        }
    }

    private var spoken: String {
        [heading, isEpisode ? line.title : nil, V2ManageSpeech.size(line.bytes), reason]
            .compactMap { $0 }.joined(separator: ", ")
    }

    /// Today a time ("06:12"), otherwise a short date and time.
    static func clock(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(date: .abbreviated, time: .shortened)
    }
}
