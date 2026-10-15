import SwiftUI
import FusionhaKit

/// Under a queue card's release name (fusionha 0.4.189): the release facts
/// parsed from its name as small chips (source or service, codec, HDR/DV,
/// audio, edition, REPACK/PROPER, group), then, for a season pack or anime
/// batch, the file count and its done / now / waiting ranges. A held pack
/// with stored decisions (0.4.196) shows "9 import-ready · 3 held · 1 already
/// owned" and its outcome runs instead, plus an amber "1080p · Mixed" chip
/// when its files differ.
struct QueueFacts: View {
    let item: QueueItem

    var body: some View {
        let chips = item.parsed?.chips ?? []
        let mixed = PackDecisions.mixedFacts(item.packMixed, parsed: item.parsed)
        if !chips.isEmpty || !mixed.isEmpty || item.packRanges != nil || item.hasPackDecisions {
            VStack(alignment: .leading, spacing: 5) {
                if !chips.isEmpty || !mixed.isEmpty {
                    ActFlow(spacing: 4, lineSpacing: 4) {
                        ForEach(mixed, id: \.key) { QueueMixedChip(fact: $0) }
                        ForEach(chips, id: \.self) { ActMonoChip(text: $0) }
                    }
                }
                if item.hasPackDecisions {
                    QueuePackDecisionsView(item: item)
                } else if let ranges = item.packRanges {
                    QueuePackLine(item: item, ranges: ranges)
                }
            }
        }
    }

}

/// "Pack · 13 files · ✓ S03E01–E04 · now E05 · then E06–E13".
struct QueuePackLine: View {
    let item: QueueItem
    let ranges: QueuePackRanges

    var body: some View {
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

/// A held pack's decisions: the summary line, then one capsule per run of
/// episodes with the same outcome (ok green, held amber, skipped dim).
struct QueuePackDecisionsView: View {
    let item: QueueItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ActFlow(spacing: 0, lineSpacing: 3) {
                if let files = item.fileCount {
                    Text("Pack · \(files) file\(files == 1 ? "" : "s")").foregroundStyle(Theme.txt)
                }
                if let text = item.packSummary?.text {
                    Text(" · ")
                    Text(text)
                }
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Theme.mut)
            .accessibilityElement(children: .combine)
            ActFlow(spacing: 4, lineSpacing: 4) {
                ForEach(Array((item.packOutcomeRanges ?? []).enumerated()), id: \.offset) { _, run in
                    QueueOutcomeRun(run: run)
                }
            }
        }
    }
}

private struct QueueOutcomeRun: View {
    let run: QueuePackOutcomeRange

    private var tint: Color {
        switch run.outcome.style {
        case .ok: return Theme.done
        case .hold: return Theme.miss
        case .skip: return Theme.dim
        }
    }

    private var icon: String {
        switch run.outcome.style {
        case .ok: return "checkmark"
        case .hold: return "circle.fill"
        case .skip: return "circle"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: run.outcome.style == .hold ? 5 : 8, weight: .bold))
            Text(run.text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// The amber "1080p · Mixed" chip; a tap shows which episodes differ.
private struct QueueMixedChip: View {
    let fact: PackDecisions.MixedFact
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Text(fact.text)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.miss)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.miss.opacity(0.14), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.miss.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fact.accessibilityLabel)
        .accessibilityHint(fact.detail)
        .popover(isPresented: $showing) {
            Text(fact.detail)
                .font(.footnote)
                .foregroundStyle(Theme.txt)
                .padding(14)
                .frame(maxWidth: 300)
                .presentationCompactAdaptation(.popover)
        }
    }
}
