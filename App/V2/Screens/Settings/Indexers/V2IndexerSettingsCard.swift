import SwiftUI
import FusionhaKit

/// The indexer's settings on its detail (mock `set`): RSS and automatic
/// search as their own switches, then the values the edit sheet sets.
/// Everything else is changed in Edit (v1's `IndexerSheet`).
struct V2IndexerSettingsCard: View {
    let indexer: SearchIndexerInfo
    let model: V2IndexersModel
    @Environment(AppModel.self) private var appModel

    private struct Fact: Identifiable {
        let title: String
        let value: String
        var id: String { title }
    }

    private var facts: [Fact] {
        var out: [Fact] = []
        if let anime = indexer.animeStandardFormatSearch {
            out.append(Fact(title: "Anime standard format", value: anime ? "On" : "Off"))
        }
        if let gap = indexer.minQueryIntervalSeconds {
            out.append(Fact(title: "Min. query interval", value: "\(gap) s"))
        }
        if let age = indexer.minimumAgeMinutes, age > 0 {
            out.append(Fact(title: "Minimum age", value: "\(age) min"))
        }
        out.append(Fact(title: "Daily query cap",
                        value: (indexer.apiDailyLimit ?? 0) > 0 ? FetchFormat.grouped(indexer.apiDailyLimit ?? 0) : "None"))
        if indexer.discoveryProbeUnlimited == true {
            out.append(Fact(title: "4K discovery probes", value: "Unlimited"))
        } else if let cap = indexer.discoveryDailyQueryCap, cap > 0 {
            out.append(Fact(title: "4K discovery probes", value: "\(FetchFormat.grouped(cap)) a day"))
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V2SettingsGroupHeader(title: "Settings")
            VStack(spacing: 0) {
                V2SettingsToggleRow(title: "RSS", isOn: flag("enabled_rss", indexer.enabledRss))
                V2SettingsHairline()
                V2SettingsToggleRow(title: "Automatic search", isOn: flag("enabled_search", indexer.enabledSearch))
                ForEach(facts) { fact in
                    V2SettingsHairline()
                    V2SettingsValueRow(title: fact.title, value: fact.value, chevron: false)
                }
            }
            .v2CardStyle(padding: 0)
        }
    }

    private func flag(_ key: String, _ value: Bool) -> Binding<Bool> {
        Binding(get: { value }, set: { model.setFlag(indexer, key, $0, client: appModel.client) })
    }
}
