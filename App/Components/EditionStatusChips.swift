import SwiftUI
import FusionhaKit

/// The content-first Library's version chips (owner-approved layout A, mock
/// `.q2`): one per version, in its tier colour (HD purple, 4K cyan) on a
/// tinted ground, a status dot coloured by `EditionStatus.color`, and a short
/// label only while the version is moving (3/5, 30%, ↓, ↑). They replace the
/// coverage rails on cards. Content, never glass.
struct EditionStatusChips: View {
    let item: MediaItem
    @Environment(AppModel.self) private var model

    var body: some View {
        let queue = model.queue
        let chips = EditionChipLabel.chips(for: item) { edition in
            queue.first { $0.editionId == edition.id }.map(Self.percent)
        }
        FlowRow(spacing: 5, lineSpacing: 5) {
            ForEach(chips.indices, id: \.self) { i in
                EditionStatusChip(chip: chips[i])
            }
        }
    }

    /// The queue row's progress: bytes when sizes are known, else the client's percent.
    static func percent(_ q: QueueItem) -> Int {
        let pct = q.size > 0 ? (q.size - q.sizeleft) / q.size * 100 : q.progress
        return min(100, max(0, Int(pct.rounded())))
    }
}

struct EditionStatusChip: View {
    let chip: EditionChipLabel

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(chip.tone.color).frame(width: 6, height: 6)
            Text(chip.tier.pill)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            if let text = chip.text {
                Text(text)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
        }
        .foregroundStyle(chip.tier.chipText)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(TierChipBackground(tier: chip.tier))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chip.tier.chipLabel), \(chip.tone.label)\(chip.text.map { ", \($0)" } ?? "")")
    }
}

extension EditionChipLabel.Tone {
    /// The dot colour, through the web's `status.ts` mapping.
    var color: Color {
        switch self {
        case .done: return EditionStatus.downloaded.color
        case .grabbing: return EditionStatus.downloading.color
        case .wanted, .attention: return EditionStatus.missing.color
        case .upgrading: return EditionStatus.upgrading.color
        case .upcoming: return EditionStatus.upcoming.color
        case .deadLink: return EditionStatus.stuck.color
        }
    }

    var label: String {
        switch self {
        case .done: return "downloaded"
        case .grabbing: return "downloading"
        case .wanted: return "missing"
        case .upgrading: return "upgrading"
        case .upcoming: return "upcoming"
        case .attention: return "files not found"
        case .deadLink: return "dead link"
        }
    }
}
