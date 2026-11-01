import SwiftUI
import FusionhaKit

/// The held download's reason strip (the web's `HeldStrip`): why it was held,
/// and for a pack, its live rows by what they would do and a pointer to the
/// bulk bar (it replaced Keep all current / Import all). Once nothing is left
/// to decide it reads Done on the imported wash.
struct MIHeldStripView: View {
    let strip: ManualImportHeldStrip
    @Environment(ManualImportSession.self) private var session
    @Environment(\.horizontalSizeClass) private var horizontalSize

    var body: some View {
        let lines = strip.lines(compact: horizontalSize == .compact)
        let done = strip.done
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: done ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(done ? Theme.done : Theme.miss)
                (Text(done ? "Done" : "Held").bold() + Text(lines.line1.map { " · " + $0 }.joined()))
                    .font(.subheadline).foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach([lines.line2, ManualImportRules.titleSummary(session.rows)].compactMap { $0 }, id: \.self) { line in
                Text(line).font(.footnote).foregroundStyle(Theme.mut).padding(.leading, 26)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if strip.bulkEligible > 0 && session.barShows {
                // The bulk bar decides several at once (approved bulk-decide v3).
                Text("Decide several together: tick them, then Import or Decide ▾.")
                    .font(.footnote).foregroundStyle(Theme.mut).padding(.leading, 26)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actWash(done ? Theme.done : Theme.miss, radius: Theme.radius, base: Theme.panel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Held download")
    }
}

/// The import bar (the web's `StickyBar` with the rescue plan, 0.4.202): the
/// import mode, and the primary the plan names: N files need a decision, Force
/// import N, Finish download (a retry), or Done; a folder scan's is the web's
/// batch "Import N" with "K need a decision" under it. Each download finishes
/// on its own as soon as its rows are decided, so there is no blocklist box.
/// It stays a custom bar for web parity (owner decision D3-B, an exception to
/// the D2 column plan); when the controls don't fit one row, the primary takes
/// a row of its own rather than truncating.
struct MIFooter: View {
    @Environment(ManualImportSession.self) private var session
    @Environment(\.verticalSizeClass) private var verticalSize

    var body: some View {
        let plan = session.plan
        VStack(alignment: .leading, spacing: 8) {
            if let notice = session.notice {
                HStack(alignment: .top) {
                    Text(notice.text).font(.footnote).foregroundStyle(notice.error ? Theme.danger : Theme.miss)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Dismiss", systemImage: "xmark") { session.notice = nil }
                        .labelStyle(.iconOnly).foregroundStyle(Theme.mut)
                }
            }
            if pendingTicked > 0 {
                Text("\(pendingTicked) file\(pendingTicked == 1 ? " is" : "s are") still being checked; the name-vs-file check hasn't run for \(pendingTicked == 1 ? "it" : "them") yet.")
                    .font(.footnote).foregroundStyle(Theme.mut)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { selection; mode(plan); Spacer(minLength: 0); MIFooterPrimary(plan: plan) }
                // The plan's narrow wording, when it has one ("7 need a decision").
                HStack(spacing: 10) { selection; mode(plan); Spacer(minLength: 0); MIFooterPrimary(plan: plan, short: true) }
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 10) { selection; mode(plan); Spacer(minLength: 0) }
                    MIFooterPrimary(plan: plan)
                }
                VStack(alignment: .trailing, spacing: 8) {
                    HStack { selection; Spacer(minLength: 0) }
                    if plan.imports > 0 { HStack { mode(plan); Spacer(minLength: 0) } }
                    MIFooterPrimary(plan: plan, short: true)
                }
            }
            // Landscape on a phone or the folded Duo: the bar keeps to its controls.
            if verticalSize != .compact {
                if let hint = plan.hint {
                    Text(hint).font(.footnote).foregroundStyle(Theme.mut)
                } else if !plan.folder {
                    Text("Imports in place, no re-download.").font(.footnote).foregroundStyle(Theme.mut)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, verticalSize == .compact ? 8 : 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    /// Nothing ticked: Select all undecided (the bar takes over once something
    /// is); a folder scan's "N selected · Actions".
    @ViewBuilder
    private var selection: some View {
        if session.barShows {
            MISelectUndecidedButton(showsCount: true)
                .buttonStyle(ActButtonStyle(kind: .ghost))
        } else {
            MISelectionMenu()
        }
    }

    @ViewBuilder
    private func mode(_ plan: ManualImportFinishPlan) -> some View {
        @Bindable var session = session
        if plan.imports > 0 {
            Menu {
                Picker("Import mode", selection: $session.importMode) {
                    ForEach(ManualImportMode.allCases) { mode in
                        Text("\(mode.label) · \(mode.hint)").tag(mode)
                    }
                }
            } label: { GlassMenuLabel(title: session.importMode.label) }
            .accessibilityLabel("Import mode, \(session.importMode.label)")
        }
    }

    private var pendingTicked: Int {
        session.rows.filter { session.selected.contains($0.rowId) && $0.probe?.isPending == true }.count
    }
}

/// "N selected · Actions" (the web's sticky-bar chip): opens the actions sheet.
/// Folder scans only while `ManualImportFeatures.barEverywhere` is off.
struct MISelectionMenu: View {
    @Environment(ManualImportSession.self) private var session
    @State private var open = false

    var body: some View {
        let count = session.rows.filter { !$0.committed && session.selected.contains($0.rowId) }.count
        Button { open = true } label: { GlassMenuLabel(title: "\(count) selected · Actions") }
            .buttonStyle(.plain)
            .disabled(session.working || session.bulkBusy)
            .accessibilityLabel("\(count) selected, actions")
            .duoPageSheet(isPresented: $open) { MISelectionSheet().environment(session) }
    }
}
