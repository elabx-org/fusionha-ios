import SwiftUI
import FusionhaKit

// Settings › Metadata's provider cards (the web's `MetadataPanel` provider
// cards): the official mark, role, status, key, test and enable, plus
// TheTVDB's required attribution line.

// MARK: Provider cards

enum MetadataProvider {
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
        case .tmdb: return ("TMDB", Theme.brand(0x01B4E4))
        case .tvdb: return ("TVDB", Theme.brand(0x6CD491))
        case .tvmaze: return ("TVmaze", Theme.brand(0x3C948B))
        }
    }

    /// The official mark (the web's card-header logo, sized for a phone row).
    @ViewBuilder
    var logo: some View {
        switch self {
        case .tmdb: TmdbLogo(size: 26, label: name)
        case .tvdb: TvdbLogo(size: 30, label: name)
        case .tvmaze: TvmazeLogo(size: 24, label: name)
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

struct ProviderCard: View {
    let provider: MetadataProvider
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsDesktop) private var desktop
    @State private var testing = false
    @State private var running = false
    @State private var testMessage: String?

    /// Phone: identity and toggle, the status line, then the cells stacked.
    /// Desktop Settings (web `.head` + `.body` 1fr 1fr): identity, status and
    /// toggle on one row, the two cells side by side with a hairline between.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                identity
                Spacer(minLength: 0)
                if desktop {
                    VStack(alignment: .trailing, spacing: 4) {
                        statusPill
                        statusMeta
                    }
                }
                toggle
            }
            if !desktop {
                HStack(spacing: 8) {
                    statusPill
                    statusMeta
                }
            }
            SettingsCellPair(sideBySide: desktop) { firstCell } trailing: { secondCell }
        }
        .padding(.vertical, 6)
        .opacity(enabled ? 1 : 0.7)
        .settingsField(provider.name)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            provider.logo
                .padding(.bottom, 6)
            Text(provider.role.uppercased())
                .font(.system(size: 11, weight: .heavy))
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
    }

    private var toggle: some View {
        Toggle("", isOn: enabledBinding)
            .labelsHidden()
            .tint(Theme.indigo)
            .disabled(provider == .tmdb)
            .accessibilityLabel(provider == .tmdb ? "TMDB is always enabled" : "Enable \(provider.mark.0) provider")
    }

    private var statusPill: some View {
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
        .animation(.easeInOut(duration: 0.2), value: status.label)
    }

    private var statusMeta: some View {
        Text(status.meta).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(1)
    }

    @ViewBuilder private var firstCell: some View {
        switch provider {
        case .tmdb:
            ApiKeyCell(key: "tmdb_api_key", configuredKey: "tmdb_configured", label: "TMDB API key",
                       sub: "Required · movies always use TMDB")
        case .tvdb:
            ApiKeyCell(key: "tvdb_api_key", configuredKey: "tvdb_configured", label: "TVDB API key",
                       sub: "BYO TVDB v4 · stored redacted")
        case .tvmaze:
            NumberFieldRow(label: "Search delay after air", description: "Wait before auto-searching", unit: "min",
                           value: store.double("search_air_delay_minutes", 15)) { n in
                store.save("search_air_delay_minutes", .number(n))
            }
        }
    }

    @ViewBuilder private var secondCell: some View {
        switch provider {
        case .tmdb:
            connectionCell(sub: "Probe the saved key against TMDB.", path: "/api/v1/settings/test-tmdb")
        case .tvdb:
            connectionCell(sub: "Probe against TheTVDB.", path: "/api/v1/settings/test-tvdb")
        case .tvmaze:
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
            .foregroundStyle(Theme.i2)
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
