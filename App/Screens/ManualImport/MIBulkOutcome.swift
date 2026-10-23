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
                MIOutcomeLines(summary: summary)
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

    var body: some View {
        let outcome = summary.outcome(pick ?? summary.preferred)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(outcome.enumerated()), id: \.offset) { i, line in
                Text(line)
                    .font(.subheadline.weight(i == 0 ? .semibold : .regular))
                    .foregroundStyle(i == 0 ? Theme.txt : Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(summary.reasons.all + [summary.decidedNote].compactMap { $0 }, id: \.self) { line in
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
