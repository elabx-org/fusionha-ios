import SwiftUI
import FusionhaKit

/// A pack's one line and thin bar, then the expandable file ranges (web
/// `PackSection`): "Linking 4 of 13 · S03E01–S03E04 ✓ · S03E05 · then caching
/// and validating". A held pack with stored decisions reads "13 files linked ·
/// 9 import-ready · 3 held · 1 already owned", then its outcome runs beside the
/// files toggle. The same at 13, 52 or 112+ files.
struct QueuePackSection: View {
    let item: QueueItem
    @Environment(\.actReduceMotion) private var reduce
    @State private var open = false

    /// A pack line is drawn for a pack, or a held pack with decisions.
    static func shows(_ item: QueueItem) -> Bool {
        QueuePackModel.isPack(item) || item.hasPackDecisions
    }

    var body: some View {
        let model = QueuePackModel(item: item)
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                line(model)
                ActProgressBar(fraction: model.fraction, height: 3, fill: AnyShapeStyle(Theme.grab),
                               shimmer: false, mono: .grab)
                    .accessibilityLabel("\(model.done) of \(model.total) files linked")
            }
            if model.decided {
                ActFlow(spacing: 4, lineSpacing: 4) {
                    ForEach(Array((item.packOutcomeRanges ?? []).enumerated()), id: \.offset) { _, run in
                        QueueOutcomeRun(run: run)
                    }
                    toggle(model)
                }
            } else {
                toggle(model)
            }
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    if let release = item.releaseTitle {
                        Text(release)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                            .textSelection(.enabled)
                    }
                    QueuePackRanges(downloadId: item.id, model: model)
                }
                .transition(.opacity)
            }
        }
    }

    private func line(_ model: QueuePackModel) -> some View {
        ActFlow(spacing: 8, lineSpacing: 3) {
            Text(model.headline).fontWeight(.semibold).foregroundStyle(Theme.txt)
            if !model.decided, !model.summary.isEmpty { Text(model.summary) }
            if let then = model.then { Text(then) }
            if model.decided, !model.summary.isEmpty {
                Text(model.summary).foregroundStyle(Theme.miss)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.mut)
        .accessibilityElement(children: .combine)
    }

    private func toggle(_ model: QueuePackModel) -> some View {
        Button {
            if reduce { open.toggle() } else { withAnimation(.easeOut(duration: 0.16)) { open.toggle() } }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(open ? 90 : 0))
                Text("\(model.total) files")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(open ? "Expanded" : "Collapsed")
    }
}

/// One run of a held pack's episodes with the same outcome: "E01–E09 import-ready".
struct QueueOutcomeRun: View {
    let run: QueuePackOutcomeRange

    var body: some View {
        HStack(spacing: 4) {
            QueuePackGlyph(style: run.outcome.style)
            Text(run.text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(QueuePackGlyph.tint(run.outcome.style))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(QueuePackGlyph.tint(run.outcome.style).opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// ok: check · hold: dot · skip: ring, in the run's tone.
struct QueuePackGlyph: View {
    let style: QueuePackOutcome.Style

    static func tint(_ style: QueuePackOutcome.Style) -> Color {
        switch style {
        case .ok: return Theme.done
        case .hold: return Theme.miss
        case .skip: return Theme.dim
        }
    }

    var body: some View {
        Group {
            switch style {
            case .ok: Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
            case .hold: Circle().frame(width: 6, height: 6)
            case .skip: Circle().strokeBorder(lineWidth: 1.5).frame(width: 8, height: 8)
            }
        }
        .foregroundStyle(Self.tint(style))
        .frame(width: 12)
        .accessibilityHidden(true)
    }
}
