import SwiftUI
import FusionhaKit

/// The tabs' one version filter on the folded Duo / phone: a native menu with
/// All versions, then each tracked version, a checkmark on the current one.
/// It sets the page scope, the same state a Versions card opens, and stands in
/// for the "Tabs show" chip and the "showing …" echo of the wide layout.
struct DetailVersionMenu: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail

    var body: some View {
        Menu {
            Picker("Show in the tabs", selection: selection) {
                Text("All versions").tag(Int?.none)
                ForEach(detail.versionsSorted) { edition in
                    Text(detail.versionName(edition)).tag(Int?.some(edition.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            DetailGlassLabel(systemImage: "line.3.horizontal.decrease", text: store.showingLabel, height: 36)
                .contentTransition(.opacity)
        }
        .fixedSize()
        .accessibilityLabel("Version shown in the tabs")
        .accessibilityValue(store.showingLabel)
    }

    private var selection: Binding<Int?> {
        Binding(get: { store.focusedVersion?.id }, set: { id in
            if let id, let edition = detail.versionsSorted.first(where: { $0.id == id }) {
                store.scope = DetailScope(tier: edition.tier.rawValue, version: edition.versionKey)
            } else {
                store.scope = .all
            }
        })
    }
}
