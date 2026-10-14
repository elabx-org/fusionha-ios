import SwiftUI
import FusionhaKit

/// The held download's reason strip (the web's `HeldStrip`): why it was held,
/// and for a pack, Keep all current / Import all over the held downgrades.
struct MIHeldStripView: View {
    let strip: ManualImportHeldStrip
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Theme.miss)
                (Text("Held").bold() + Text(strip.line1.map { " · " + $0 }.joined()))
                    .font(.subheadline).foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach([strip.line2, ManualImportRules.titleSummary(session.rows)].compactMap { $0 }, id: \.self) { line in
                Text(line).font(.footnote).foregroundStyle(Theme.mut).padding(.leading, 26)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if strip.bulkEligible > 0 {
                HStack(spacing: 8) {
                    Button("Keep all current", systemImage: "internaldrive") { Task { await session.bulkHeld("keep_current") } }
                        .buttonStyle(ActButtonStyle(kind: .subtle))
                    Button("Import all", systemImage: "arrow.down") { Task { await session.bulkHeld("import") } }
                        .buttonStyle(ActButtonStyle(kind: .subtle))
                }
                .disabled(session.bulkBusy || session.working)
                .padding(.leading, 26)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.miss.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.miss.opacity(0.25)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Held download")
    }
}

/// The import bar (the web's `StickyBar` with the rescue plan): the import
/// mode, the primary the plan names, and the blocklist box or kept-files note.
struct MIFooter: View {
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        @Bindable var session = session
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
            HStack(spacing: 10) {
                if plan.imports > 0 {
                    Menu {
                        Picker("Import mode", selection: $session.importMode) {
                            ForEach(ManualImportMode.allCases) { mode in
                                Text("\(mode.label) — \(mode.hint)").tag(mode)
                            }
                        }
                    } label: { GlassMenuLabel(title: session.importMode.label) }
                    .accessibilityLabel("Import mode, \(session.importMode.label)")
                }
                Spacer(minLength: 0)
                Button { Task { await session.runPrimary() } } label: {
                    HStack(spacing: 6) {
                        if session.working { ProgressView().controlSize(.small).tint(Theme.onPrimary) }
                        else { Image(systemName: plan.kind == .keep ? "internaldrive" : "square.and.arrow.down") }
                        Text(session.working ? (plan.finishes ? "Working…" : "Importing…") : plan.label)
                    }
                }
                .buttonStyle(ActButtonStyle(kind: .primary))
                .disabled(plan.disabled || session.working || session.bulkBusy)
                .opacity(plan.disabled ? 0.5 : 1)
            }
            if session.showBlocklist {
                Toggle(isOn: $session.blocklist) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Blocklist this release").font(.subheadline)
                        Text("So it is not grabbed again").font(.caption).foregroundStyle(Theme.mut)
                    }
                }
                .tint(Theme.i1)
            } else if plan.kind == .keep && session.guarded {
                Label("The guard already blocklisted this release", systemImage: "checkmark.shield")
                    .font(.footnote).foregroundStyle(Theme.done)
            }
            if let hint = plan.hint {
                Text(hint).font(.footnote).foregroundStyle(Theme.mut)
            } else {
                Text("Imports in place, no re-download.").font(.footnote).foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var pendingTicked: Int {
        session.rows.filter { session.selected.contains($0.rowId) && $0.probe?.isPending == true }.count
    }
}
