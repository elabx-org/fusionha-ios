import SwiftUI
import FusionhaKit

/// The bulk bar's Decide menu (owner-approved "bar in every scenario", iOS
/// pass): Keep current (with the held download's disposition as a submenu),
/// Skip, then Confirm N medium matches, Import mode (only while Import is
/// possible) and Edit N selected…. Each item's second line is what it does, or
/// why it is off. The prominent Import N sits beside the menu, not in it.
struct MIDecideMenuItems: View {
    @Binding var editing: Bool
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        @Bindable var session = session
        let s = session.bulk
        Section {
            keep(s)
            Button { run(.skip) } label: {
                Label(s.skipLabel, systemImage: "forward")
                Text(s.skipOutcome ?? s.reasons.skip ?? "Only for files with no copy in your library.")
            }
            .disabled(s.skip.isEmpty)
        }
        Section {
            let confirm = session.tickedToConfirm
            if !confirm.isEmpty {
                Button("Confirm \(confirm.count) medium match\(confirm.count == 1 ? "" : "es")", systemImage: "questionmark.diamond") {
                    Task { await session.confirm(confirm) }
                }
            }
            if !s.imp.isEmpty {
                Picker(selection: $session.importMode) {
                    ForEach(ManualImportMode.allCases) { mode in
                        Text("\(mode.label) · \(mode.hint)").tag(mode)
                    }
                } label: {
                    Label("Import mode", systemImage: "arrow.triangle.branch")
                    Text(session.importMode.label)
                }
                .pickerStyle(.menu)
            }
            Button("Edit \(s.open.count) selected…", systemImage: "pencil") { editing = true }
                .disabled(s.open.isEmpty)
        }
        Section {
            Button("Clear selection", systemImage: "xmark.circle") { session.selected = [] }
        }
    }

    /// Keep current: a disposition submenu while a download is held, else one
    /// action ("nothing imported, your library file stays").
    @ViewBuilder private func keep(_ s: ManualImportBulkSummary) -> some View {
        let title = "Keep current \(s.of(s.keep.count))"
        if s.held && !s.dispositions.isEmpty {
            Menu {
                ForEach(s.dispositions) { d in
                    Button { run(.keepCurrent, pick: d.value) } label: {
                        Text(d.recommended ? "\(d.label) · Recommended" : d.label)
                        Text(d.off ?? d.detail)
                    }
                    .disabled(d.off != nil)
                }
            } label: {
                Label(title, systemImage: "internaldrive")
                Text(s.keepOutcome(s.preferred) ?? "")
            }
        } else {
            Button { run(.keepCurrent) } label: {
                Label(s.keep.isEmpty ? "Keep current" : title, systemImage: "internaldrive")
                Text(s.keepOutcome(s.preferred) ?? s.reasons.keep ?? "")
            }
            .disabled(s.keep.isEmpty)
        }
    }

    private func run(_ action: ManualImportDecideAction, pick: FinishDisposition? = nil) {
        Task { await session.decide(action, pick: pick) }
    }
}
