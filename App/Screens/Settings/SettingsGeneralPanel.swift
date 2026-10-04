import SwiftUI
import FusionhaKit

/// Settings → General (the web's `GeneralPanel.tsx`): app behaviour, search
/// scheduling, 4K discovery, run history and download handling. Every control
/// saves its own key as soon as it changes.
struct GeneralSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @Environment(\.settingsPush) private var push
    @State private var advancedOpen = false

    var body: some View {
        SettingsForm(slug: "general") {
            RecommendedSetupSection()
            if !store.loaded {
                SettingsLoadingRow()
            } else if let error = store.error, store.values.isEmpty {
                SettingsLoadingRow(error: error)
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        SettingsSection {
            SettingToggle(key: "animations_enabled", label: "Enable animations",
                          description: "Turn off for reduced motion — the whole UI drops to instant transitions.",
                          fallback: true)
            SettingToggle(key: "voice_playful", label: "Playful voice",
                          description: "Keep the app's characterful microcopy — turn off for plain, neutral wording.",
                          fallback: true)
            SettingToggle(key: "real_integrations", label: "Real integrations",
                          description: "Use live indexers & download clients instead of stubs.")
            SettingPicker(label: "RSS interval", description: "Clamped to a safe floor to avoid indexer bans.",
                          options: rssOptions, selection: store.intBinding("rss_interval_seconds", 900))
            SettingPicker(label: "First day of week",
                          description: "The day the calendar's month & week grids start on (arr parity).",
                          options: [(0, "Sunday"), (1, "Monday"), (6, "Saturday")],
                          selection: store.intBinding("first_day_of_week", 0))
            SettingPicker(label: "Default calendar view",
                          description: "The view the calendar opens on (an explicit link or a remembered choice still wins).",
                          options: [("month", "Month"), ("week", "Week"), ("forecast", "Forecast"), ("day", "Day"), ("agenda", "Agenda")],
                          selection: store.stringBinding("calendar_default_view", "month"))
            SettingPicker(label: "Week card style",
                          description: "How each event card looks in the calendar's Week view (the Week toolbar cog sets the same thing).",
                          options: [("landscape", "Landscape still"), ("portrait", "Portrait poster"),
                                    ("compact", "Compact"), ("accent", "Tier accent")],
                          selection: store.stringBinding("calendar_week_card_style", "landscape"))
            AppApiKeyRow(label: "fusionha API key",
                         description: "Authenticate external tools against fusionha's own /api/v1 with an X-Api-Key header.")
            SettingValueRow(label: "Setup wizard",
                            description: "Re-run the first-run onboarding (welcome → TMDB → roots → import).") {
                Button("Run wizard") { push("import") }
                    .buttonStyle(.web())
            }
            SettingValueRow(label: "About", description: "The running fusionha version.") {
                ServerVersionText()
            }
        }

        SettingsSection("Search") {
            SettingNumber(key: "availability_delay_days", label: "Availability delay",
                          description: "Search this many days before (−) or after (+) a movie becomes available. 0 = exactly on the available date.",
                          unit: "days", signed: true)
            SettingToggle(key: "search_on_add", label: "Search on add",
                          description: "When adding a title, immediately search for its monitored editions (a per-add choice can still override this).",
                          fallback: true)
            SettingNumber(key: "season_search_interval_seconds", label: "Season episode-search interval",
                          description: "Seconds between each episode when a season uses 'Search each episode (gradual)' instead of a season-pack search.",
                          unit: "sec")
        }

        SettingsSection("Missing (Wanted) search") {
            SettingToggle(key: "missing_search_enabled", label: "Automatic missing search",
                          description: "Periodically search for monitored titles still missing a file for a monitored edition.")
            SettingNumber(key: "missing_search_interval_seconds", label: "Search interval",
                          description: "How often the missing-search sweep runs. Clamped to a safe floor to avoid indexer bans.",
                          unit: "sec")
            SettingNumber(key: "missing_search_max_items", label: "Items per run",
                          description: "Cap on how many titles one missing-search sweep works through (oldest first), so a big backlog drains across runs.",
                          unit: "items")
        }

        SettingsSection("Cutoff upgrade search") {
            SettingToggle(key: "cutoff_unmet_search_enabled", label: "Automatic cutoff-unmet search",
                          description: "Periodically re-search monitored editions whose file is below the profile cutoff, looking for an upgrade. Heavier on indexers — off by default.")
            SettingNumber(key: "cutoff_unmet_search_interval_seconds", label: "Search interval",
                          description: "How often the cutoff-upgrade sweep runs. Clamped to a safe floor to avoid indexer bans.",
                          unit: "sec")
            SettingNumber(key: "missing_search_max_items", label: "Cutoff items per run",
                          description: "Cap on how many below-cutoff editions one cutoff-upgrade sweep works through (oldest first), so a big backlog drains across runs.",
                          unit: "items")
        }

        SettingsSection("Recent-upgrade retry") {
            SettingToggle(key: "active_upgrade_search_enabled", label: "Retry recent grabs for an upgrade",
                          description: "A gentle, small lane that re-checks recently imported editions still below cutoff for a better release — so a fresh episode's upgrade isn't starved behind the big oldest-first backlog.")
            SettingNumber(key: "active_upgrade_window_days", label: "Recent window",
                          description: "Only editions imported within this many days are eligible for the recent-upgrade lane; older ones hand back to the daily cutoff sweep.",
                          unit: "days")
            SettingNumber(key: "active_upgrade_search_interval_seconds", label: "Search interval",
                          description: "How often the recent-upgrade lane runs. Clamped to a safe floor to avoid indexer bans (kept gentle by default).",
                          unit: "sec")
            SettingNumber(key: "active_upgrade_max_items", label: "Items per run",
                          description: "Cap on how many recently imported editions the recent-upgrade lane works through (newest first).",
                          unit: "items")
        }

        SettingsSection("4K discovery") {
            SettingToggle(key: "uhd_available_observer_enabled", label: "Observe 4K availability",
                          description: "Learn where 4K exists for HD titles from searches you already run — no extra queries.")
            SettingNumber(key: "uhd_available_staleness_days", label: "Keep 4K sightings fresh for (days)",
                          description: "An observed 2160p sighting older than this is treated as stale and dropped from the 4K Available tab.",
                          unit: "days")
            SettingToggle(key: "discovery_probe_enabled", label: "Actively probe for 4K",
                          description: "Spend indexer queries to check HD titles that searches never touch. Off by default; only queries indexers you've flagged unlimited or given a daily cap.")
            SettingNumber(key: "discovery_probe_max_items_per_run", label: "Titles per probe run",
                          description: "Cap on how many titles one discovery-probe sweep works through, so a big library drains across runs.",
                          unit: "items")
            SettingNumber(key: "discovery_probe_interval_seconds", label: "Probe interval (seconds)",
                          description: "How often the discovery-probe sweep runs. Clamped to a safe floor to avoid indexer bans.",
                          unit: "sec")
        }

        SettingsSection("Activity & run history") {
            SettingNumber(key: "run_retention_days", label: "Keep run history for",
                          description: "How long completed search, RSS and import runs are kept before they're pruned from Activity. The most recent runs are always retained regardless of age.",
                          unit: "days")
        }

        SettingsSection("Download handling") {
            SettingValueRow(label: "Advanced download handling",
                            description: "Grace and timeout windows for how long a stuck or vanished download waits before fusionha fails and re-searches it.") {
                Button(advancedOpen ? "Hide advanced" : "Show advanced") {
                    SettingsMotion.perform(motionOff) { advancedOpen.toggle() }
                }
                .buttonStyle(.web(.ghost))
            }
            if advancedOpen {
                SettingNumber(key: "stale_download_grace_minutes", label: "Vanished download grace",
                              description: "Minutes after grab before a download the client no longer knows about is declared vanished, then failed and re-searched.",
                              unit: "min")
                SettingNumber(key: "queue_stalled_after_minutes", label: "Stalled display threshold",
                              description: "Minutes a frozen 0% download sits before it's flagged as stalled in the queue (a display signal only).",
                              unit: "min")
                SettingNumber(key: "stalled_download_timeout_minutes", label: "Stalled download timeout",
                              description: "Minutes a download may stay queued at 0% before it's failed and re-searched. 0 disables the timeout.",
                              unit: "min")
                SettingNumber(key: "regrab_cooldown_hours", label: "Re-grab cooldown",
                              description: "How long a removed/failed release stays excluded before it can be re-grabbed. 0 disables the cooldown.",
                              unit: "hrs", max: 168)
            }
        }
    }

    /// The four presets, plus the stored value when it is something else.
    private var rssOptions: [(Int, String)] {
        var options = [(900, "15 minutes"), (1800, "30 minutes"), (3600, "1 hour"), (7200, "2 hours")]
        let current = store.int("rss_interval_seconds", 900)
        if !options.contains(where: { $0.0 == current }) {
            options.append((current, "\(current / 60) minutes"))
        }
        return options
    }
}

/// The web's `RecommendedSetup`: the first-run order, each step deep-linking
/// to its panel. Dismissible; the choice is remembered on this device.
private struct RecommendedSetupSection: View {
    @AppStorage("fusionha.setup-order.dismissed") private var dismissed = false
    @Environment(\.settingsMotionOff) private var motionOff

    private struct Step: Identifiable {
        let id: Int
        let label, group, slug, why: String
        var optional = false
    }

    private let steps: [Step] = [
        Step(id: 1, label: "General", group: "app basics", slug: "general", why: "name, auth, base settings"),
        Step(id: 2, label: "Metadata", group: "TMDB", slug: "metadata", why: "the provider titles resolve against"),
        Step(id: 3, label: "Root Folders", group: "Media Management", slug: "roots", why: "where each tier's files live"),
        Step(id: 4, label: "Quality Definitions", group: "Quality", slug: "qualitydefinitions", why: "size limits per quality"),
        Step(id: 5, label: "Custom Formats", group: "Quality", slug: "formats", why: "the scoring rules profiles use"),
        Step(id: 6, label: "Quality Profiles", group: "Quality", slug: "profiles", why: "allowed qualities + cutoff + scores"),
        Step(id: 7, label: "Default Profiles", group: "Quality", slug: "defaultprofiles", why: "the profile each kind × tier gets — needs 3 + 6"),
        Step(id: 8, label: "Naming & File Management", group: "Media Management", slug: "naming", why: "optional — how files are named + handled", optional: true),
        Step(id: 9, label: "Download Clients + Indexers", group: "Fetching", slug: "clients", why: "how releases are grabbed"),
        Step(id: 10, label: "Import Library", group: "Media Management", slug: "import", why: "adopt your existing collection — uses all the above"),
    ]

    var body: some View {
        if !dismissed {
            Section {
                ForEach(steps) { step in
                    NavigationLink(value: step.slug) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(step.id)")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundStyle(Theme.cyan)
                                .frame(width: 20, height: 20)
                                .background(Theme.cyan.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.label)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(Theme.txt)
                                Text("\(step.group) · \(step.why)")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.mut)
                            }
                        }
                        .opacity(step.optional ? 0.6 : 1)
                    }
                }
            } header: {
                HStack {
                    Text("Recommended setup order")
                        .font(.system(size: 12.5, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.mut)
                    Spacer()
                    Button("Dismiss") {
                        SettingsMotion.perform(motionOff) { dismissed = true }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .textCase(nil)
                }
            }
            .listRowBackground(Theme.card)
        }
    }
}

/// The app API key control shared by General and Security: masked until
/// Reveal, then Copy / Hide; Regenerate asks first, then shows the new key once.
struct AppApiKeyRow: View {
    @Environment(SettingsStore.self) private var store
    let label: String
    var description: String?
    @State private var shown: String?
    @State private var copied = false
    @State private var busy = false
    @State private var confirmRegenerate = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(label: label, description: description)
            if let shown {
                Text(shown)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                    .textSelection(.enabled)
            } else {
                MonoText(store.bool("app_key_configured") ? "•••• •••• ••••" : "Not set")
            }
            HStack(spacing: 8) {
                if shown != nil {
                    Button(copied ? "Copied" : "Copy") { copy() }.buttonStyle(.web())
                    Button("Hide") { shown = nil }.buttonStyle(.web(.ghost))
                } else {
                    Button("Reveal") { Task { await reveal() } }.buttonStyle(.web()).disabled(busy)
                }
                Button("Regenerate") { confirmRegenerate = true }.buttonStyle(.web()).disabled(busy)
            }
            if let error {
                Text(error).font(.system(size: 12)).foregroundStyle(Theme.danger)
            }
        }
        .padding(.vertical, 4)
        .settingsField(label)
        .confirmationDialog("Regenerate the app API key?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Regenerate key", role: .destructive) { Task { await regenerate() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anything using the current key stops working until you give it the new one.")
        }
    }

    private func copy() {
        guard let shown else { return }
        UIPasteboard.general.string = shown
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
        }
    }

    private func reveal() async {
        guard let client = store.client else { return }
        busy = true
        defer { busy = false }
        do {
            shown = try await client.revealAppApiKey()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func regenerate() async {
        guard let client = store.client else { return }
        busy = true
        defer { busy = false }
        do {
            shown = try await client.regenerateAppApiKey()
            error = nil
            await store.load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// `v<version>` from `GET /api/v1/system/status`.
struct ServerVersionText: View {
    @Environment(SettingsStore.self) private var store
    @State private var version: String?

    var body: some View {
        MonoText(version.map { "v\($0)" } ?? "—")
            .task {
                version = try? await store.client?.json("GET", "/api/v1/system/status")["version"]?.string
            }
    }
}
