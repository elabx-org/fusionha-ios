import SwiftUI
import FusionhaKit

/// The bulk outcome card on the phone and the folded Duo (owner-approved item
/// 4): the first outcome line alone, with More to read the rest (the other
/// outcome lines and why an action is off). Collapses again when the
/// selection's words change, so it never hides a new answer half-open.
struct MIOutcomeOneLine: View {
    let summary: ManualImportBulkSummary
    @State private var expanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var shownHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let lines = summary.outcome(summary.preferred)
        let first = lines.first ?? ""
        let reasons = summary.reasons.all + [summary.decidedNote].compactMap { $0 }
        let more = lines.count > 1 || !reasons.isEmpty || fullHeight > shownHeight + 1
        Group {
            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    MIOutcomeLines(summary: summary)
                    toggle
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    line(first)
                    Spacer(minLength: 0)
                    if more { toggle }
                }
            }
        }
        .onChange(of: lines) { expanded = false }
    }

    private func line(_ first: String) -> some View {
        Text(first)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.txt)
            .lineLimit(1)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownHeight = $0 }
            .background(alignment: .topLeading) {
                // The uncapped height, to know whether one line cut it.
                Text(first).font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
            }
    }

    private var toggle: some View {
        Button(expanded ? "Less" : "More") {
            withAnimation(reduceMotion ? nil : .snappy) { expanded.toggle() }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.accentText)
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityLabel(expanded ? "Show less" : "Show the whole outcome")
    }
}
