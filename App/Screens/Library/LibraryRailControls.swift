import SwiftUI
import FusionhaKit

/// The coverage-rail display (RailStyleControls.tsx): the four styles with a
/// preview rail, and Consolidate HD + 4K. Admins write it to Settings; others
/// see why they can't. In the phone's Filters sheet and the wide toolbar's
/// Display options.
struct LibraryRailControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let isAdmin = model.me?.isAdmin == true
        VStack(alignment: .leading, spacing: 8) {
            ForEach(RailStyle.allCases, id: \.self) { style in
                Button {
                    Task { await model.updateRails(style: style) }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                            Text(style.hint).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                        }
                        Spacer(minLength: 8)
                        RailRowView(rail: Rail(state: .owned, progress: 100, fraction: nil, attention: false, deadLinkOnly: false),
                                    tier: .hd, size: 12_800_000_000)
                            .environment(\.railStyle, style)
                            .frame(width: 110)
                    }
                    .padding(12)
                    .background(model.railStyle == style ? Theme.i2.opacity(0.08) : Theme.panel,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(model.railStyle == style ? Theme.i2.opacity(0.6) : Theme.line))
                }
                .buttonStyle(.plain)
                .disabled(!isAdmin)
            }
            Toggle(isOn: Binding(get: { model.railConsolidate },
                                 set: { value in Task { await model.updateRails(consolidate: value) } })) {
                Text("Consolidate HD + 4K").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            .tint(Theme.indigo)
            .disabled(!isAdmin)
            if !isAdmin {
                Text("Set by admin — only administrators can change the library coverage-rail display.")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
        }
    }
}
