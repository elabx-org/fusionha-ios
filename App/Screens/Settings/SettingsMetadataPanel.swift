import SwiftUI
import FusionhaKit

/// Settings → Metadata (the web's `MetadataPanel.tsx`): one card per provider
/// (status, key, test, enable), the default series provider with the Hybrid
/// precedence editor, refresh cadences and episode numbering.
struct MetadataSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var advancedOpen = false

    var body: some View {
        SettingsForm(slug: "metadata") {
            if !store.loaded {
                SettingsLoadingRow()
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        SettingsSection("Metadata sources") {
            ProviderCard(provider: .tmdb)
        }
        SettingsSection(footer: "Metadata provided by TheTVDB. Please consider adding missing information or subscribing.") {
            ProviderCard(provider: .tvdb)
        }
        SettingsSection {
            ProviderCard(provider: .tvmaze)
        }

        SettingsSection("Default series provider") {
            VStack(alignment: .leading, spacing: 10) {
                FieldLabel(label: "Default provider",
                           description: "Global default for series (movies always use TMDB). A per-series override on the title’s detail page wins over this.")
                Picker("Default provider", selection: providerBinding) {
                    Text("TMDB").tag("tmdb")
                    Text("TVDB").tag("tvdb")
                    Text("TVmaze").tag("tvmaze")
                    Text("Hybrid").tag("hybrid")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
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

// MARK: Provider cards

private enum MetadataProvider {
    case tmdb, tvdb, tvmaze

    var name: String {
        switch self {
        case .tmdb: return "The Movie Database"
        case .tvdb: return "TheTVDB"
        case .tvmaze: return "TVmaze"
        }
    }

    var role: String {
        switch self {
        case .tmdb: return "Identity · Primary"
        case .tvdb: return "Series provider · augment"
        case .tvmaze: return "Air times · numbering"
        }
    }

    var blurb: String {
        switch self {
        case .tmdb: return "Movies, series & anime · TVDB/IMDB → TMDB translation for arr clients."
        case .tvdb: return "Alternate series numbering · tvdb_id backfill · adding series missing from TMDB."
        case .tvmaze: return "Free · no API key. Network air time + timezone per episode, and an alternate numbering source."
        }
    }

    var mark: (String, Color) {
        switch self {
        case .tmdb: return ("TMDB", Color(hex: 0x01B4E4))
        case .tvdb: return ("TVDB", Color(hex: 0x6CD491))
        case .tvmaze: return ("TVmaze", Color(hex: 0x3C948B))
        }
    }
}

private struct ProviderStatus {
    enum Kind { case ok, ready, off, err, testing }
    let kind: Kind
    let label: String
    let meta: String

    var color: Color {
        switch kind {
        case .ok: return Theme.done
        case .ready: return Theme.cyan
        case .off: return Theme.dim
        case .err: return Theme.danger
        case .testing: return Theme.miss
        }
    }
}

private struct ProviderCard: View {
    let provider: MetadataProvider
    @Environment(SettingsStore.self) private var store
    @State private var testing = false
    @State private var running = false
    @State private var testMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(provider.mark.0)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(provider.mark.1)
                    .frame(width: 46, height: 46)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.role.uppercased())
                        .font(.system(size: 9.5, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(Theme.dim)
                    Text(provider.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.txt)
                    Text(provider.blurb)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .tint(Theme.indigo)
                    .disabled(provider == .tmdb)
                    .accessibilityLabel(provider == .tmdb ? "TMDB is always enabled" : "Enable \(provider.mark.0) provider")
            }
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(status.color).frame(width: 6, height: 6)
                    Text(status.label)
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(status.color)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(status.color.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(status.color.opacity(0.32)))
                Text(status.meta).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            .animation(.easeInOut(duration: 0.2), value: status.label)
            switch provider {
            case .tmdb:
                ApiKeyCell(key: "tmdb_api_key", configuredKey: "tmdb_configured", label: "TMDB API key",
                           sub: "Required · movies always use TMDB")
                connectionCell(sub: "Probe the saved key against TMDB.", path: "/api/v1/settings/test-tmdb")
            case .tvdb:
                ApiKeyCell(key: "tvdb_api_key", configuredKey: "tvdb_configured", label: "TVDB API key",
                           sub: "BYO TVDB v4 · stored redacted")
                connectionCell(sub: "Probe against TheTVDB.", path: "/api/v1/settings/test-tvdb")
            case .tvmaze:
                NumberFieldRow(label: "Search delay after air", description: "Wait before auto-searching", unit: "min",
                               value: store.double("search_air_delay_minutes", 15)) { n in
                    store.save("search_air_delay_minutes", .number(n))
                }
                HStack {
                    FieldLabel(label: "Enrichment", description: enrichmentSub)
                    Spacer()
                    Button {
                        Task { await runEnrichment() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.web())
                    .disabled(running || !store.bool("tvmaze_enabled"))
                    .accessibilityLabel(running ? "Running…" : "Run enrichment now")
                }
            }
        }
        .padding(.vertical, 6)
        .opacity(enabled ? 1 : 0.7)
        .settingsField(provider.name)
    }

    private var enabled: Bool {
        switch provider {
        case .tmdb: return true
        case .tvdb: return store.bool("tvdb_enabled")
        case .tvmaze: return store.bool("tvmaze_enabled", true)
        }
    }

    private var enabledBinding: Binding<Bool> {
        switch provider {
        case .tmdb: return .constant(true)
        case .tvdb: return store.boolBinding("tvdb_enabled")
        case .tvmaze: return store.boolBinding("tvmaze_enabled", true)
        }
    }

    private var status: ProviderStatus {
        if testing {
            return ProviderStatus(kind: .testing, label: "Testing…",
                                  meta: provider == .tmdb ? "probing TMDB" : "probing TheTVDB")
        }
        switch provider {
        case .tmdb:
            return keyedStatus(configured: store.bool("tmdb_configured"), tested: store.string("tmdb_last_tested_at"),
                               ok: store.bool("tmdb_last_test_ok"))
        case .tvdb:
            if !store.bool("tvdb_enabled") {
                return ProviderStatus(kind: .off, label: "Disabled",
                                      meta: store.bool("tvdb_configured") ? "key stored · inactive" : "not configured")
            }
            return keyedStatus(configured: store.bool("tvdb_configured"), tested: store.string("tvdb_last_tested_at"),
                               ok: store.bool("tvdb_last_test_ok"))
        case .tvmaze:
            if !store.bool("tvmaze_enabled", true) { return ProviderStatus(kind: .off, label: "Disabled", meta: "inactive") }
            let synced = store.string("tvmaze_last_synced_at")
            return ProviderStatus(kind: .ok, label: "Active",
                                  meta: synced.isEmpty ? "not yet synced" : "synced \(formatAgo(synced))")
        }
    }

    private func keyedStatus(configured: Bool, tested: String, ok: Bool) -> ProviderStatus {
        if !configured { return ProviderStatus(kind: .err, label: "Error", meta: "no API key configured") }
        if tested.isEmpty { return ProviderStatus(kind: .ready, label: "Ready", meta: "configured · not tested") }
        if ok { return ProviderStatus(kind: .ok, label: "Connected", meta: "verified \(formatAgo(tested))") }
        return ProviderStatus(kind: .err, label: "Error", meta: "failed \(formatAgo(tested))")
    }

    private var enrichmentSub: String {
        let synced = store.string("tvmaze_last_synced_at")
        return Format.timestamp(synced) == nil ? "Never run yet" : "Last filled \(formatAgo(synced))"
    }

    private func connectionCell(sub: String, path: String) -> some View {
        HStack {
            FieldLabel(label: "Connection", description: testMessage ?? sub)
            Spacer()
            Button {
                Task { await test(path) }
            } label: {
                Image(systemName: "bolt")
            }
            .buttonStyle(.web())
            .foregroundStyle(Theme.cyan)
            .disabled(testing)
            .accessibilityLabel(testing ? "Testing…" : "Test connection")
        }
    }

    private func test(_ path: String) async {
        guard let client = store.client else { return }
        testing = true
        let result = try? await client.json("POST", path)
        testMessage = result?["message"]?.string
        // The probe always stamps last-tested on the server; re-read for the pill.
        await store.load()
        testing = false
    }

    private func runEnrichment() async {
        running = true
        _ = try? await store.client?.json("POST", "/api/v1/system/tasks/air-times/run")
        running = false
    }
}

/// A masked key with a pencil; editing shows a secure field with Save / Cancel.
private struct ApiKeyCell: View {
    let key: String
    let configuredKey: String
    let label: String
    let sub: String
    @Environment(SettingsStore.self) private var store
    @State private var editing = false
    @State private var value = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FieldLabel(label: label, description: sub)
                Spacer()
                if !editing {
                    MonoText(store.bool(configuredKey) ? "•••• •••• ••••" : "Not set")
                    Button { editing = true } label: { Image(systemName: "pencil") }
                        .buttonStyle(.web())
                        .accessibilityLabel("Change \(label)")
                }
            }
            if editing {
                SecureField("", text: $value, prompt: Text("Paste your \(label)").foregroundStyle(Theme.dim))
                    .font(.system(size: 13))
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
                    .onSubmit(commit)
                HStack(spacing: 8) {
                    Button("Save", action: commit)
                        .buttonStyle(.web(.primary))
                        .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") { editing = false; value = "" }
                        .buttonStyle(.web(.ghost))
                }
            }
        }
    }

    private func commit() {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.save(key, .string(trimmed))
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await store.load()
        }
        editing = false
        value = ""
    }
}

/// The web's `formatAgo`: "just now", "5 min ago", "3h ago", "2d ago", or a date.
func formatAgo(_ iso: String) -> String {
    guard let then = Format.timestamp(iso) else { return "" }
    let secs = max(0, Int(Date().timeIntervalSince(then)))
    if secs < 60 { return "just now" }
    let mins = secs / 60
    if mins < 60 { return "\(mins) min ago" }
    let hrs = mins / 60
    if hrs < 24 { return "\(hrs)h ago" }
    let days = hrs / 24
    if days < 7 { return "\(days)d ago" }
    return then.formatted(date: .numeric, time: .omitted)
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
                                Text(Self.sourceLabel[source] ?? source)
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
