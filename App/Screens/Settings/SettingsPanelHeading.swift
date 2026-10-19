import SwiftUI

/// Every Settings panel's standard header: the panel title in the display
/// face over its subtitle (from `SettingsNav`). `SettingsForm` puts it in its
/// first section; panels that aren't forms (Rules) put it at the top.
struct SettingsPanelHeading: View {
    let slug: String

    private var info: SettingsPanelInfo? { SettingsNav.panel(slug) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info?.title ?? slug)
                .pageTitle(36)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Text(info?.subtitle ?? "")
                .font(.system(size: 15))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
