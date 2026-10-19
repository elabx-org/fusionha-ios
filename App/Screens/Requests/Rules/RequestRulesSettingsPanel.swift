import SwiftUI

/// Settings › Requests › Rules (`/settings/request-rules`, old slug
/// `requestrules`): the Rules page on the settings ground, with the same
/// large inline title every native panel carries (`SettingsForm`).
struct RequestRulesSettingsPanel: View {
    var body: some View {
        ScrollView {
            RequestRulesView()
                .padding(16)
        }
        .background(Theme.bg)
        .settingsPanelTitle("request-rules")
    }
}
