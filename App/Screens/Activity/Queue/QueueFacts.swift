import SwiftUI
import FusionhaKit

/// Under a queue card's release name (fusionha 0.4.189): the release facts
/// parsed from its name as small chips (source or service, codec, HDR/DV,
/// audio, edition, REPACK/PROPER, group), then, for a season pack or anime
/// batch, the file count and its done / now / waiting ranges.
struct QueueFacts: View {
    let item: QueueItem

    var body: some View {
        let chips = item.parsed?.chips ?? []
        if !chips.isEmpty || item.packRanges != nil {
            VStack(alignment: .leading, spacing: 5) {
                if !chips.isEmpty {
                    ActFlow(spacing: 4, lineSpacing: 4) {
                        ForEach(chips, id: \.self) { ActMonoChip(text: $0) }
                    }
                }
                if let ranges = item.packRanges { pack(ranges) }
            }
        }
    }

    private func pack(_ ranges: QueuePackRanges) -> some View {
        ActFlow(spacing: 0, lineSpacing: 3) {
            if let files = item.fileCount {
                Text("Pack · \(files) file\(files == 1 ? "" : "s")").foregroundStyle(Theme.txt)
            }
            if let done = ranges.done {
                Text(" · ")
                Text("✓ \(done.label)").foregroundStyle(Theme.done)
            }
            if let current = ranges.current {
                Text(" · ")
                Text("now \(current.label)").foregroundStyle(Theme.grab)
            }
            if let waiting = ranges.waiting {
                Text(" · ")
                Text("then \(waiting.label)")
            }
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(Theme.mut)
        .accessibilityElement(children: .combine)
    }
}
