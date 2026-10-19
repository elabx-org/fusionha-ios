import SwiftUI
import WebKit
import FusionhaKit

// MARK: Experimental

struct ExperimentalSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff

    var body: some View {
        SettingsForm(slug: "experimental") {
            if !store.loaded {
                SettingsLoadingRow()
            } else {
                SettingsSection {
                    Toggle(isOn: store.boolBinding("experimental_search_improvements")) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EXPERIMENTAL")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(Theme.miss)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.miss.opacity(0.45)))
                            FieldLabel(label: "Smarter automatic searches",
                                       description: "Improve fusionha's automatic replacement searches: it avoids re-grabbing a release that just failed (anti-thrash), paces retries so a bad night doesn't thrash your indexers, re-searches whole season packs, and ranks results by indexer priority and recency. Experimental — turn it off any time to restore the previous behaviour.")
                        }
                    }
                    .tint(Theme.indigo)
                    .settingsField("Smarter automatic searches")
                }
                SettingsSection("Fine-tuning") {
                    SettingNumber(key: "usenet_cross_indexer_retry_budget", label: "Usenet retry budget",
                                  description: "How many different copies of the same release to try across indexers before giving that title a rest (0 = don't retry across indexers).",
                                  unit: "copies", disabled: !enabled)
                    SettingNumber(key: "usenet_title_condemn_cooldown_seconds", label: "Condemned-title cool-off",
                                  description: "How long a title that used up its retry budget stays out of the automatic search rotation before it's tried again.",
                                  unit: "seconds", disabled: !enabled)
                    SettingNumber(key: "failed_research_burst_threshold", label: "Rapid-failure guard",
                                  description: "After this many quick failures in a row, hold off on the immediate replacement search and let things settle first.",
                                  unit: "failures", disabled: !enabled)
                    SettingNumber(key: "failed_research_min_interval_seconds", label: "Retry pacing",
                                  description: "Minimum time between replacement searches for one slot once the rapid-failure guard trips (0 = no pacing).",
                                  unit: "seconds", disabled: !enabled)
                    SettingText(key: "failed_grab_cooldown_schedule_seconds", label: "Failed-grab cool-off schedule",
                                description: "Escalating per-slot cool-offs after consecutive failed grabs — a comma-separated list of seconds, e.g. 0,300,900,1800. Empty disables it.")
                        .disabled(!enabled)
                }
                .opacity(enabled ? 1 : 0.55)
                .animation(motionOff ? nil : .easeInOut(duration: 0.2), value: enabled)
            }
        }
    }

    private var enabled: Bool { store.bool("experimental_search_improvements") }
}
