import SwiftUI
import FusionhaKit

/// The open iPhone Duo's right page while files are ticked (owner-approved
/// bulk-decide mock, iOS pass): "N selected · Clear", what each ticked file
/// can take, Keep current's disposition as radios with the pre-pick (a held
/// download) or one line (any other scan), Skip, the outcome, then Keep
/// current N and Import N. Import mode, Confirm medium and Edit N are glass
/// chips under them. Solid content on the page; only the chips are glass.
struct MIDecidePanel: View {
    @Environment(ManualImportSession.self) private var session
    @State private var picked: FinishDisposition?
    @State private var editing = false

    var body: some View {
        let s = session.bulk
        let pick = effectivePick(s)
        let busy = session.applying != nil || session.working || session.bulkBusy
        VStack(alignment: .leading, spacing: 16) {
            header(s)
            MIBreakdown(lines: s.lines)
            Divider().overlay(Theme.line)
            keepSection(s, pick: pick)
            skipSection(s)
            Group {
                if let applying = session.applying {
                    MIApplyingLine(applying: applying, held: s.held)
                } else {
                    MIOutcomeLines(summary: s, pick: pick)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            if let notice = session.notice {
                Text(notice.text).font(.footnote).foregroundStyle(notice.error ? Theme.danger : Theme.miss)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ActFlow(spacing: 8, lineSpacing: 8) {
                ActAsyncButton(label: MIBulkWords.keepTitle(s, applying: nil), systemImage: "internaldrive",
                               kind: s.imp.isEmpty ? .primary : .subtle,
                               workingLabel: MIBulkWords.keepTitle(s, applying: session.applying)) {
                    await session.decide(.keepCurrent, pick: pick)
                    return session.notice?.error != true
                }
                .disabled(s.keep.isEmpty || busy)
                ActAsyncButton(label: MIBulkWords.importTitle(s, applying: nil), systemImage: "square.and.arrow.down",
                               kind: .primary, workingLabel: MIBulkWords.importTitle(s, applying: session.applying)) {
                    await session.decide(.importFile)
                    return session.notice?.error != true
                }
                .disabled(s.imp.isEmpty || busy)
            }
            MIDecideChips(summary: s, editing: $editing).disabled(busy)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: session.selected) { picked = nil }
        .duoPageSheet(isPresented: $editing) {
            MIBulkSheet(title: "Edit \(s.open.count) selected", rows: s.open).environment(session)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Decide the selected files")
    }

    /// The radio pick while it is still offered, else the pre-pick.
    private func effectivePick(_ s: ManualImportBulkSummary) -> FinishDisposition {
        guard let picked, s.dispositions.contains(where: { $0.value == picked && $0.off == nil }) else { return s.preferred }
        return picked
    }

    private func header(_ s: ManualImportBulkSummary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(s.n) selected").font(.title3.weight(.semibold)).foregroundStyle(Theme.txt)
            Spacer(minLength: 8)
            Button("Clear") { session.selected = [] }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accentText)
                .disabled(session.applying != nil)
        }
    }

    @ViewBuilder private func keepSection(_ s: ManualImportBulkSummary, pick: FinishDisposition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keep current").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
            if s.held && !s.dispositions.isEmpty {
                ForEach(s.dispositions) { d in
                    MIDispositionRow(option: d, on: d.value == pick) { picked = d.value }
                }
            } else {
                Text(s.keepOutcome(pick) ?? s.reasons.keep ?? "Nothing imported, your library file stays.")
                    .font(.footnote).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func skipSection(_ s: ManualImportBulkSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.skipLabel).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                Text(s.skipOutcome ?? s.reasons.skip ?? "Only for files with no copy in your library.")
                    .font(.footnote).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ActAsyncButton(label: "Skip", systemImage: "forward", kind: .subtle) {
                await session.decide(.skip)
                return session.notice?.error != true
            }
            .disabled(s.skip.isEmpty || session.applying != nil || session.working)
        }
    }
}

/// "E02  keep current (not an upgrade)": each ticked file and what it can take.
struct MIBreakdown: View {
    let lines: [ManualImportBulkSummary.Line]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(lines) { line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(line.code)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.txt)
                        .frame(minWidth: 40, alignment: .leading)
                    Text(line.text).font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// One Keep current disposition as a radio: label, Recommended on a
/// non-default pre-pick, and what it does (or why it is off).
struct MIDispositionRow: View {
    let option: ManualImportBulkSummary.Disposition
    let on: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle").foregroundStyle(on ? Theme.i1 : Theme.dim)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(option.label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        if option.recommended {
                            Text("Recommended").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.done)
                        }
                    }
                    Text(option.off ?? option.detail).font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .strokeBorder(on ? Theme.i1 : Theme.line, lineWidth: on ? 1.5 : 1))
            .opacity(option.off == nil ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(option.off != nil)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
