import SwiftUI
import FusionhaKit

/// One sideways row of glass filter chips (mock `K.chips`): the chosen chip
/// is the accent glass (selection), the rest plain glass; a count rides in
/// the chip.
struct V2GlassChips<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: String
        var count: Int?
        var id: Value { value }
    }

    let options: [Option]
    @Binding var selection: Value
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(options) { chip($0) }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(_ option: Option) -> some View {
        let on = option.value == selection
        return Button {
            withAnimation(motion ? .snappy(duration: 0.25) : nil) { selection = option.value }
        } label: {
            HStack(spacing: 4) {
                Text(option.label)
                if let count = option.count {
                    Text(count.formatted()).font(.system(size: 11.5, weight: .bold).monospacedDigit()).opacity(0.8)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(on ? Theme.onAccent : Theme.txt)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(Theme.primary).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// One labelled amount as a one-ink bar (mock `.lg-bar`, drawn to the rails
/// rule: the label ink on the empty track, no status hues).
struct V2InkBarRow: View {
    let label: String
    let value: String
    let fraction: Double
    var labelWidth: CGFloat = 96
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            RailBarV2(spans: fraction > 0 ? [OneInkRail.Span(piece: .onDisk, fraction: min(1, fraction))] : [])
            Text(value)
                .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

/// A number over its label (mock `.lg-kv`).
struct V2KeyFigure: View {
    let value: String
    let label: String
    var tint: Color?
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint ?? page?.ink ?? Theme.txt)
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
        }
        .accessibilityElement(children: .combine)
    }
}
