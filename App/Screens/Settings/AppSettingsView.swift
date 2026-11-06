import SwiftUI
import FusionhaKit

/// Settings as each product draws it: v2's S1 Settings (`V2SettingsView`)
/// in the v2 app, v1's `SettingsView` otherwise. Every entry point (the
/// avatar menu, Library stats, Requests' rules) opens it through here.
struct AppSettingsView: View {
    let client: APIClient?
    var initialPanel: String?

    var body: some View {
        #if V2
        V2SettingsView(client: client, initialPanel: initialPanel)
        #else
        SettingsView(client: client, initialPanel: initialPanel)
        #endif
    }
}
