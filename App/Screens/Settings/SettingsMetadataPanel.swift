import SwiftUI
import FusionhaKit

/// Settings → Metadata (the web's `MetadataPanel.tsx`): one card per provider
/// (status, key, test, enable), the default series provider with the Hybrid
/// precedence editor, refresh cadences and episode numbering.
struct MetadataSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @Environment(SettingsFlash.self) private var flash
    @State private var advancedOpen = false

    var body: some View {
        SettingsForm(slug: "metadata") {
            if !store.loaded {
                SettingsLoadingRow()
            } else {
                content
            }
        }
        #if DEBUG
        .task(id: store.loaded) {
            // CI screenshots: scroll to a field (`FUSIONHA_SCREENSHOT_METADATA_SCROLL=Default provider`).
            guard store.loaded, let label = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_METADATA_SCROLL"]
            else { return }
            try? await Task.sleep(for: .milliseconds(600))
            flash.set(panel: "metadata", label: label)
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        SettingsSection("Metadata sources") {
            ProviderCard(provider: .tmdb)
        }
        Section {
            ProviderCard(provider: .tvdb)
        } footer: {
            TvdbAttribution()
        }
        .listRowBackground(Theme.card)
        .listRowSeparatorTint(Theme.line)
        SettingsSection {
            ProviderCard(provider: .tvmaze)
        }

        SettingsSection("Default series provider") {
            VStack(alignment: .leading, spacing: 10) {
                FieldLabel(label: "Default provider",
                           description: "Global default for series (movies always use TMDB). A per-series override on the title’s detail page wins over this.")
                MetadataProviderSegmented(selection: providerBinding,
                                          disabled: store.bool("tvdb_configured") ? [] : ["tvdb", "hybrid"])
                // TVDB / Hybrid need a configured TVDB key (the server answers 422
                // `tvdb_not_configured`): they stay visible but can't be picked.
                if !store.bool("tvdb_configured") {
                    Text("TVDB · Hybrid: Needs a TVDB key")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                    if ["tvdb", "hybrid"].contains(store.string("metadata_provider", "tmdb")) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "key")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.miss)
                            let name = store.string("metadata_provider", "tmdb") == "hybrid" ? "Hybrid" : "TVDB"
                            Text("Your default is \(Text(name).bold()), but no TVDB key is configured — series fall back to TMDB/TVmaze until you add one above.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.txt)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.miss.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .settingsField("Default provider")
            if store.string("metadata_provider", "tmdb") == "hybrid" {
                HybridPrecedenceRows()
            }
        }

        SettingsSection("Metadata refresh") {
            SettingNumber(key: "metadata_refresh_interval_seconds", label: "Full refresh interval",
                          description: "How often the full library metadata sweep re-pulls titles, runtimes and artwork from TMDB.",
                          unit: "sec")
            SettingValueRow(label: "Advanced cadences",
                            description: "Fast active-series sweep, episode-title watch, and TVmaze air-time refresh timings.") {
                Button {
                    SettingsMotion.perform(motionOff) { advancedOpen.toggle() }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.web(advancedOpen ? .subtle : .ghost))
                .accessibilityLabel(advancedOpen ? "Hide advanced cadences" : "Show advanced cadences")
            }
            if advancedOpen {
                SettingNumber(key: "metadata_refresh_active_interval_seconds", label: "Active-series refresh interval",
                              description: "Faster sweep that re-syncs only series with a monitored episode airing inside the active window below.",
                              unit: "sec")
                SettingNumber(key: "metadata_refresh_active_window_days", label: "Active window",
                              description: "How near an episode's air date a series counts as active for the faster sweep (± this many days).",
                              unit: "days")
                SettingNumber(key: "title_watch_interval_seconds", label: "Episode-title watch interval",
                              description: "Cheap tick that refreshes only episodes still carrying a placeholder title and due per an air-age backoff.",
                              unit: "sec")
                SettingNumber(key: "tvmaze_air_times_imminent_interval_seconds", label: "Air-time refresh — imminent",
                              description: "How often TVmaze air times refresh for a series whose next episode is imminent (≤ 3 days away).",
                              unit: "sec")
                SettingNumber(key: "tvmaze_air_times_soon_interval_seconds", label: "Air-time refresh — soon",
                              description: "Refresh cadence for a series whose next episode is soon (≤ 14 days away).",
                              unit: "sec")
                SettingNumber(key: "tvmaze_air_times_default_interval_seconds", label: "Air-time refresh — default",
                              description: "Refresh cadence for everything else (next episode far off, or none scheduled).",
                              unit: "sec")
            }
        }

        SettingsSection("Episode numbering") {
            SettingToggle(key: "episode_numbering_autodetect", label: "Auto-detect mismatches",
                          description: "Periodically checks each series' current numbering against TVmaze and flags a mismatch for review — never changes anything on its own.")
            SettingToggle(key: "episode_numbering_autoapply", label: "Auto-apply the fix",
                          description: "When a mismatch is unambiguous — sources agree, every file re-links cleanly, no active queue — apply it automatically instead of waiting for review.")
            SettingToggle(key: "episode_numbering_exclude_anime", label: "Exclude anime",
                          description: "Skip anime titles in both automatic checks above — absolute numbering makes a TVmaze mismatch ambiguous. An admin can still fix an anime series manually from its detail page.")
            SettingToggle(key: "episode_numbering_include_specials", label: "Include specials",
                          description: "Fold Season 0 (specials) into the TVmaze comparison. Off by default — specials ordering is the least consistent data across sources, so a specials-only difference is normally ignored rather than flagged or renumbered.")
        }
    }

    private var providerBinding: Binding<String> {
        Binding(get: { store.string("metadata_provider", "tmdb") },
                set: { value in
                    if ["tvdb", "hybrid"].contains(value), !store.bool("tvdb_configured") { return }
                    store.save("metadata_provider", .string(value))
                })
    }
}

// MARK: Hybrid precedence

/// "✦ Hybrid — per-field source precedence": tap a source to promote it.
private struct HybridPrecedenceRows: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff

    private static let fields: [(id: String, label: String, description: String)] = [
        ("title", "Title · Overview · Artwork", "names, summaries, posters"),
        ("numbering", "Episode order / numbering", "season & episode numbers"),
        ("airtimes", "Air times", "network time + timezone"),
        ("identity", "Identity / IDs", "the item's canonical id"),
        ("status", "Status / lifecycle", "continuing / ended"),
    ]

    private static let defaults: [String: [String]] = [
        "title": ["tmdb", "tvdb"],
        "numbering": ["tvdb", "tvmaze", "tmdb"],
        "airtimes": ["tvmaze", "tmdb"],
        "identity": ["tmdb", "tvdb"],
        "status": ["tvdb", "tmdb"],
    ]

    private static let sourceLabel = ["tmdb": "TMDB", "tvdb": "TVDB", "tvmaze": "TVmaze"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("✦ Hybrid — per-field source precedence")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.txt)
                Spacer()
                Button("Reset to recommended") { save(Self.defaults) }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.cyan)
                    .buttonStyle(.plain)
            }
            Text("Each field is filled from the first enabled source that has it. Tap a source to promote it to primary. The highlighted chip wins.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mut)
        }
        .padding(.vertical, 4)
        ForEach(Self.fields, id: \.id) { field in
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(label: field.label, description: field.description)
                HStack(spacing: 6) {
                    let chain = order[field.id] ?? []
                    ForEach(Array(chain.enumerated()), id: \.element) { index, source in
                        if index > 0 { Text("→").font(.system(size: 12)).foregroundStyle(Theme.dim) }
                        Button { promote(field.id, source) } label: {
                            HStack(spacing: 5) {
                                ProviderMark(provider: source, size: 14)
                                if index == 0 {
                                    Text("PRIMARY").font(.system(size: 8.5, weight: .heavy)).foregroundStyle(Theme.cyan)
                                }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(index == 0 ? Theme.txt : Theme.mut)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(index == 0 ? Theme.cyan.opacity(0.12) : Theme.panel,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(index == 0 ? Theme.cyan.opacity(0.45) : Theme.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Promote \(Self.sourceLabel[source] ?? source) to primary for \(field.label)")
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var order: [String: [String]] {
        let stored = store["metadata_hybrid_precedence"]?.object ?? [:]
        var out: [String: [String]] = [:]
        for field in Self.fields {
            let cleaned = (stored[field.id]?.array ?? []).compactMap(\.string).filter { Self.sourceLabel[$0] != nil }
            out[field.id] = cleaned.isEmpty ? Self.defaults[field.id] : cleaned
        }
        return out
    }

    private func promote(_ field: String, _ source: String) {
        var next = order
        next[field] = [source] + (next[field] ?? []).filter { $0 != source }
        save(next)
    }

    private func save(_ next: [String: [String]]) {
        SettingsMotion.perform(motionOff) {
            store.save("metadata_hybrid_precedence", .object(next.mapValues { .array($0.map(JSONValue.string)) }))
        }
    }
}
