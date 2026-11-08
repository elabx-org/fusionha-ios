import SwiftUI

/// Overview's quick values (mock settings-v2.js `generalRight`): the search
/// schedule and calendar settings as plain rows with their current values.
/// Each opens General on that setting, flashed as a search hit is. Values
/// come from the server's settings; nothing shows until they load.
struct V2SettingsQuickValues: View {
    let select: (String) -> Void
    @Environment(SettingsStore.self) private var store
    @Environment(SettingsFlash.self) private var flash

    private struct Value: Identifiable {
        /// The General panel's row label (what the flash finds).
        let field: String
        let title: String
        let value: String
        var id: String { field }
    }

    private var search: [Value] {
        [
            Value(field: "RSS interval", title: "RSS interval",
                  value: Self.duration(store.int("rss_interval_seconds", 900))),
            Value(field: "Automatic missing search", title: "Missing search",
                  value: store.bool("missing_search_enabled")
                    ? Self.every(store.int("missing_search_interval_seconds", 43200)) : "Off"),
            Value(field: "Automatic cutoff-unmet search", title: "Cutoff upgrade search",
                  value: store.bool("cutoff_unmet_search_enabled")
                    ? Self.every(store.int("cutoff_unmet_search_interval_seconds", 86400)) : "Off"),
            Value(field: "Observe 4K availability", title: "4K discovery",
                  value: store.bool("uhd_available_observer_enabled") ? "On" : "Off"),
        ]
    }

    private var calendar: [Value] {
        let day = [0: "Sunday", 1: "Monday", 6: "Saturday"][store.int("first_day_of_week", 0)] ?? "Sunday"
        let view = store.string("calendar_default_view", "month")
        return [
            Value(field: "First day of week", title: "First day of week", value: day),
            Value(field: "Default calendar view", title: "Default view", value: view.prefix(1).uppercased() + view.dropFirst()),
        ]
    }

    var body: some View {
        if store.loaded, !store.values.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                V2SettingsGroupHeader(title: "Search", top: 12)
                card(search)
                V2SettingsGroupHeader(title: "Calendar", top: 12)
                card(calendar)
            }
        }
    }

    private func card(_ values: [Value]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.element.id) { index, item in
                Button {
                    flash.set(panel: "general", label: item.field)
                    select("general")
                } label: {
                    V2SettingsValueRow(title: item.title, value: item.value)
                }
                .buttonStyle(V2SettingsPressStyle())
                .accessibilityHint("Opens General")
                .overlay(alignment: .top) {
                    if index > 0 { V2SettingsHairline() }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous))
        .background { ModuleSurface() }
    }

    /// 900 → "15 min", 3600 → "1 h", 86400 → "1 d".
    static func duration(_ seconds: Int) -> String {
        if seconds >= 86_400, seconds % 86_400 == 0 { return "\(seconds / 86_400) d" }
        if seconds >= 3_600, seconds % 3_600 == 0 { return "\(seconds / 3_600) h" }
        return "\(max(1, seconds / 60)) min"
    }

    /// 43200 → "Every 12 h", 86400 → "Daily", 604800 → "Weekly".
    static func every(_ seconds: Int) -> String {
        switch seconds {
        case 86_400: return "Daily"
        case 604_800: return "Weekly"
        default: return "Every " + duration(seconds)
        }
    }
}
