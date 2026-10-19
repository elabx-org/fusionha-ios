import SwiftUI

/// Settings › Requests › Rules (`/settings/request-rules`, old slug
/// `requestrules`): the Rules page on the settings ground, with the same
/// inline navigation title every native panel carries (`SettingsForm`).
struct RequestRulesSettingsPanel: View {
    var body: some View {
        ScrollView {
            RequestRulesView()
                .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle(SettingsNav.panel("request-rules")?.title ?? "Rules")
        .navigationBarTitleDisplayMode(.inline)
    }
}
