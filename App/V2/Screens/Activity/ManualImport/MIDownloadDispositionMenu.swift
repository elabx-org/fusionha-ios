import SwiftUI
import FusionhaKit

/// "Download · Remove ▾" (mock `mi-foot .dl`): what happens to the held
/// download once its files are decided, for the files kept. Remove options
/// need `system.admin` (v1's rule); without it only Leave is offered and the
/// menu says who can remove. A leave chosen on another file stands.
struct MIDownloadDispositionMenu: View {
    let summary: ManualImportBulkSummary
    @Environment(V2MIDraftStore.self) private var store
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        let current = store.effectiveDisposition(summary)
        VStack(alignment: .leading, spacing: 3) {
            Text("Download")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.mut)
            Menu {
                ForEach(summary.dispositions) { d in
                    Button { store.disposition = d.value } label: {
                        if d.value == current { Image(systemName: "checkmark") }
                        Text(d.recommended ? "\(d.label) · Recommended" : d.label)
                        Text(d.off ?? d.detail)
                    }
                    .disabled(d.off != nil)
                }
                if !session.canRemove {
                    Text("Only an admin can remove a held download.")
                }
            } label: {
                HStack(spacing: 5) {
                    Text(Self.short(current))
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13.5, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 36)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Download, when this pack is done")
            .accessibilityValue(Self.short(current))
        }
        .fixedSize()
    }

    static func short(_ d: FinishDisposition) -> String {
        switch d {
        case .remove: return "Remove"
        case .removeBlocklist: return "Remove + blocklist"
        case .leave: return "Leave"
        }
    }
}
