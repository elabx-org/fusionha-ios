import SwiftUI
import FusionhaKit

/// What the ticked files' decision does, above the bulk bar: the outcome
/// ("Import 2 · E01 and E06 import in place"), then why an action is off for
/// some of them, then the last refusal. While a decide runs it is an
/// indeterminate progress line instead (rows lock until the answer). Solid
/// content (the bar is the glass), so it reads on every palette.
struct MIBulkOutcome: View {
    let summary: ManualImportBulkSummary
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let applying = session.applying {
                MIApplyingLine(applying: applying, held: summary.held)
            } else {
                // Compact over the list: the Decide menu says why an action is off.
                MIOutcomeLines(summary: summary, reasonLines: 2)
            }
            if let notice = session.notice {
                HStack(alignment: .top) {
                    Text(notice.text).font(.footnote).foregroundStyle(notice.error ? Theme.danger : Theme.miss)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Dismiss", systemImage: "xmark") { session.notice = nil }
                        .labelStyle(.iconOnly).foregroundStyle(Theme.mut)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: .rect(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.line))
        .accessibilityElement(children: .contain)
    }
}

/// The outcome lines, the reasons an action is off and the already-decided
/// note (the bar's card and the open Duo's panel share them).
struct MIOutcomeLines: View {
    let summary: ManualImportBulkSummary
    /// Keep current's disposition (the panel's radios), else the pre-pick.
    var pick: FinishDisposition?
    /// The reasons' line cap (the phone card), nil for all of them.
    var reasonLines: Int?

    var body: some View {
        let outcome = summary.outcome(pick ?? summary.preferred)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(outcome.enumerated()), id: \.offset) { i, line in
                Text(line)
                    .font(.subheadline.weight(i == 0 ? .semibold : .regular))
                    .foregroundStyle(i == 0 ? Theme.txt : Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let reasons = summary.reasons.all + [summary.decidedNote].compactMap { $0 }
            if !reasons.isEmpty {
                MIReasonsText(text: reasons.joined(separator: " "), lines: reasonLines)
            }
        }
    }
}

/// Why an action is off for some of the ticked files. On the phone card it is
/// capped, with More to read the rest when it runs over (F9).
struct MIReasonsText: View {
    let text: String
    /// The cap, nil for every line.
    let lines: Int?
    @State private var expanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var shownHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.dim)
                .lineLimit(expanded ? nil : lines)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownHeight = $0 }
                .background(alignment: .topLeading) {
                    // The uncapped height, to know whether the cap cut anything.
                    if lines != nil {
                        Text(text).font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                            .hidden()
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
                    }
                }
            if lines != nil && (expanded || fullHeight > shownHeight + 1) {
                Button(expanded ? "Less" : "More") {
                    withAnimation(reduceMotion ? nil : .snappy) { expanded.toggle() }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accentText)
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .accessibilityLabel(expanded ? "Show fewer reasons" : "Show all reasons")
            }
        }
        .onChange(of: text) { expanded = false }
    }
}

/// A decide in flight: indeterminate (the server answers once, all or nothing).
struct MIApplyingLine: View {
    let applying: ManualImportSession.Applying
    let held: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.mut)
                Text(applying.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
            }
            let line = ManualImportBulkSummary.applyingLine(applying.outcome, held: held)
            if !line.isEmpty {
                Text(line).font(.footnote).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
