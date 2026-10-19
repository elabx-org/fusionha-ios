import SwiftUI

/// Every Settings panel's standard header: the panel's subtitle (from
/// `SettingsNav`). The title is the system bar's, large and inline (D1).
/// `SettingsForm` puts it in its first section; panels that aren't forms
/// (Rules) put it at the top and name themselves with `settingsPanelTitle`.
struct SettingsPanelHeading: View {
    let slug: String

    private var info: SettingsPanelInfo? { SettingsNav.panel(slug) }

    var body: some View {
        Text(info?.subtitle ?? "")
            .font(.system(size: 15))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// A pushed Settings panel's title in the system bar (`.inlineLarge`).
    func settingsPanelTitle(_ slug: String) -> some View {
        navigationTitle(SettingsNav.panel(slug)?.title ?? slug)
            .toolbarTitleDisplayMode(.inlineLarge)
    }
}
