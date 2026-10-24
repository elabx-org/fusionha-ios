import SwiftUI
import FusionhaKit

/// The Spread / Web layout switch in every tab's bar while the iPhone Duo is
/// open (a top-to-bottom fold, flat or Book). A system toolbar button, symbol
/// and title, naming the mode it switches to; iOS places it (the vertical bar
/// on the Duo). Per device, stored with `DuoOpenLayout.storageKey`.
struct DuoLayoutToolbarItem: ToolbarContent {
    let shown: Bool
    @Binding var layout: DuoOpenLayout

    var body: some ToolbarContent {
        if shown {
            ToolbarItem(placement: .topBarTrailing) {
                let target = layout.other
                Button { layout = target } label: {
                    Label(target.title, systemImage: target.symbol)
                }
                .accessibilityLabel("Switch to \(target.title)")
                .accessibilityHint("Changes how the open iPhone Duo lays out")
            }
            .barPriority(true)
        }
    }
}

/// Settings › Appearance › "iPhone Duo, open". Always listed (Settings has no
/// fold of its own to read when it opens as a sheet), with a footer saying it
/// only applies to an open iPhone Duo.
struct DuoOpenLayoutSection: View {
    @AppStorage(DuoOpenLayout.storageKey) private var layout: DuoOpenLayout = .standard

    var body: some View {
        SettingsSection("iPhone Duo, open",
                        footer: "Only this iPhone, and only while an iPhone Duo is open. Spread puts the list on the left and what you pick on the right: a narrow list beside a wide page when the Duo lies flat, where the sidebar button can hide the list, and equal pages split at the fold when it is partly folded. Web layout matches the web app's wide layout. The same switch is in the toolbar while the Duo is open.") {
            Picker("iPhone Duo, open", selection: $layout) {
                ForEach(DuoOpenLayout.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .settingsField("iPhone Duo, open")
    }
}
