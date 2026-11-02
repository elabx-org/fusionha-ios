import SwiftUI
import FusionhaKit

/// The file sheet's lifted card: Quality, Video, Audio, Release group,
/// Size · length and On disk, two to a row.
struct EpisodeFileFactsCard: View {
    let facts: EpisodeFileFacts
    let onDisk: String
    /// Its own lifted card (the file sheet), or bare inside another card.
    var framed = true

    var body: some View {
        if framed {
            grid
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel(Theme.card, radius: 16)
        } else {
            grid.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var grid: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 14) {
            GridRow {
                cell("Quality", facts.quality,
                     tint: facts.belowTier ? EditionStatus.upgrading.color : Theme.txt)
                cell("Video", facts.video)
            }
            GridRow {
                cell("Audio", facts.audioWithLanguages)
                cell("Release group", facts.group)
            }
            GridRow {
                cell("Size · length", facts.sizeAndLength)
                cell("On disk", onDisk, tint: facts.deadLink ? Theme.stuck : Theme.done)
            }
        }
    }

    private func cell(_ label: String, _ value: String?, tint: Color = Theme.txt) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.dim)
            Text(value ?? "—")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(value == nil ? Theme.dim : tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The full path in mono, selectable, with Copy.
struct EpisodeFilePathBox: View {
    let path: String
    let copy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(path)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: copy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.i2)
            .accessibilityLabel("Copy path")
        }
        .padding(12)
        .panel(Theme.card, radius: 12)
    }
}
