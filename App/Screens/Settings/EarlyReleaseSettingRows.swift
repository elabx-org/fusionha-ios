import SwiftUI

/// General → Search's early-release rows (fusionha 0.4.242, web
/// `EarlyReleaseRows`): the switch, then its three thresholds, which dim and
/// disable while it is off. Each saves on its own, like every other row.
struct EarlyReleaseSettingRows: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let on = store.bool("early_release_detection_enabled", true)
        SettingToggle(key: "early_release_detection_enabled", label: "Grab early releases",
                      description: "If good Blu-ray or WEB-DL releases show up before TMDB's digital or disc date, treat the movie as out and grab it.",
                      fallback: true)
        SettingNumber(key: "early_release_min_groups", label: "Release groups needed",
                      description: "Different release groups that must have posted it.",
                      unit: "groups", min: 1, max: 100, disabled: !on)
        SettingNumber(key: "early_release_min_indexers", label: "Or indexers carrying one release",
                      description: "Or one release seen on this many indexers.",
                      unit: "indexers", min: 1, max: 100, disabled: !on)
        SettingNumber(key: "early_release_min_age_hours", label: "Wait before trusting",
                      description: "How long a release must be out first, so fakes get pulled.",
                      unit: "hours", min: 0, max: 720, disabled: !on)
    }
}
