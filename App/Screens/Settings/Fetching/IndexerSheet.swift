import SwiftUI
import FusionhaKit

/// The rich indexer dialog: master Enable, connection, categories, priority,
/// discovery budget, usenet age gate, series scope, the arr enable flags, torrent
/// seed criteria and an in-form Test. An enabled indexer must pass its test to save.
struct IndexerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let indexer: SearchIndexerInfo?
    let onSaved: () async -> Void

    @State private var name: String
    @State private var proto: String
    @State private var baseUrl: String
    @State private var apiKey = ""
    @State private var apiPath: String
    @State private var categories: String
    @State private var animeCategories: String
    @State private var animeStandardFormat: Bool
    @State private var masterEnabled: Bool
    @State private var enabledRss: Bool
    @State private var enabledSearch: Bool
    @State private var enabledInteractive = true
    @State private var priority: String
    @State private var minInterval: String
    @State private var minimumAge: String
    @State private var probeUnlimited: Bool
    @State private var dailyCap: String
    @State private var scopeOverride: String
    @State private var minSeeders = "1"
    @State private var seedRatio = ""
    @State private var seedTime = ""
    @State private var result: ConnectionTestResult?
    @State private var blocked = false
    @State private var busy = false
    @State private var testing = false

    init(indexer: SearchIndexerInfo?, onSaved: @escaping () async -> Void) {
        self.indexer = indexer
        self.onSaved = onSaved
        _name = State(initialValue: indexer?.name ?? "")
        _proto = State(initialValue: indexer?.protocol ?? "USENET")
        _baseUrl = State(initialValue: indexer?.baseUrl ?? "")
        _apiPath = State(initialValue: indexer?.apiPath ?? "/api")
        _categories = State(initialValue: (indexer?.categories ?? []).map(String.init).joined(separator: ", "))
        _animeCategories = State(initialValue: (indexer?.animeCategories ?? (indexer == nil ? [5070] : [])).map(String.init).joined(separator: ", "))
        _animeStandardFormat = State(initialValue: indexer?.animeStandardFormatSearch ?? false)
        _masterEnabled = State(initialValue: indexer?.isEnabled ?? true)
        _enabledRss = State(initialValue: indexer?.enabledRss ?? true)
        _enabledSearch = State(initialValue: indexer?.enabledSearch ?? true)
        _priority = State(initialValue: String(indexer?.priority ?? 25))
        _minInterval = State(initialValue: String(indexer?.minQueryIntervalSeconds ?? 2))
        _minimumAge = State(initialValue: String(indexer?.minimumAgeMinutes ?? 0))
        _probeUnlimited = State(initialValue: indexer?.discoveryProbeUnlimited ?? false)
        _dailyCap = State(initialValue: indexer?.discoveryDailyQueryCap.map(String.init) ?? "")
        _scopeOverride = State(initialValue: indexer?.kindScopeOverride ?? "")
    }

    private func t(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
    private var valid: Bool { !t(name).isEmpty && !t(baseUrl).isEmpty && (indexer != nil || !t(apiKey).isEmpty) }

    var body: some View {
        FetchFormSheet(title: indexer == nil ? "Add indexer" : "Edit indexer",
                       canSave: valid && !busy && !(masterEnabled && blocked), saving: busy,
                       onCancel: { dismiss() }, onSave: save) {
            Section {
                Toggle(isOn: Binding(get: { masterEnabled }, set: { masterEnabled = $0; if !$0 { blocked = false } })) {
                    FieldLabel(label: "Enable")
                }
                .tint(Theme.indigo)
                FetchTextRow(label: "Name", text: $name)
                Picker(selection: $proto) {
                    Text("Newznab (Usenet)").tag("USENET")
                    Text("Torznab (Torrent)").tag("TORRENT")
                } label: { FieldLabel(label: "Protocol") }
                .pickerStyle(.menu).tint(Theme.mut)
                FetchTextRow(label: "Base URL", text: $baseUrl, prompt: "https://api.nzbgeek.info", mono: true, keyboard: .URL)
                FetchTextRow(label: "API key", text: $apiKey,
                             prompt: indexer?.apiKeyConfigured == true ? "•••• (unchanged)" : "", secure: true, mono: true)
                FetchTextRow(label: "API path", text: $apiPath, prompt: "/api", mono: true)
            }
            .listRowBackground(Theme.card)
            SettingsSection {
                FetchTextRow(label: "Categories", text: $categories, prompt: "2000, 5000", mono: true, keyboard: .numbersAndPunctuation)
                FetchTextRow(label: "Anime Categories", text: $animeCategories, prompt: "5070", mono: true, keyboard: .numbersAndPunctuation)
                FetchTextRow(label: "Priority", text: $priority, mono: true, keyboard: .numberPad)
                FetchTextRow(label: "Min query interval (s)", text: $minInterval, mono: true, keyboard: .numberPad)
            }
            SettingsSection {
                FetchToggleRow(label: "Unlimited queries (probe freely)", isOn: $probeUnlimited)
                FetchTextRow(label: "Daily discovery query cap", text: $dailyCap, prompt: "No cap", mono: true, keyboard: .numberPad,
                             hint: indexer?.apiDailyLimit.map { "Indexer caps limit: \($0)/day" })
                    .disabled(probeUnlimited)
                if proto == "USENET" {
                    FetchTextRow(label: "Minimum age (min)", text: $minimumAge, mono: true, keyboard: .numberPad)
                }
                if let indexer {
                    Picker(selection: $scopeOverride) {
                        Text("Auto (\(kindScopeLabel(indexer.kindScope ?? "all")))").tag("")
                        Text("All series").tag("all")
                        Text("Anime only").tag("anime")
                        Text("Non-anime").tag("non_anime")
                    } label: {
                        FieldLabel(label: "Series scope",
                                   description: "Auto follows the virtual Sonarr instances Prowlarr synced this indexer into.")
                    }
                    .pickerStyle(.menu).tint(Theme.mut)
                }
            }
            SettingsSection {
                Toggle(isOn: Binding(get: { masterEnabled && enabledRss }, set: { enabledRss = $0 })) {
                    FieldLabel(label: "Enable RSS")
                }.disabled(!masterEnabled).tint(Theme.indigo)
                Toggle(isOn: Binding(get: { masterEnabled && enabledSearch }, set: { enabledSearch = $0 })) {
                    FieldLabel(label: "Enable Automatic Search")
                }.disabled(!masterEnabled).tint(Theme.indigo)
                Toggle(isOn: Binding(get: { masterEnabled && enabledInteractive }, set: { enabledInteractive = $0 })) {
                    FieldLabel(label: "Enable Interactive Search")
                }.disabled(!masterEnabled).tint(Theme.indigo)
                FetchToggleRow(label: "Anime Standard Format Search", isOn: $animeStandardFormat)
            }
            if proto == "TORRENT" {
                SettingsSection {
                    FetchTextRow(label: "Minimum seeders", text: $minSeeders, mono: true, keyboard: .numberPad)
                    FetchTextRow(label: "Seed ratio", text: $seedRatio, prompt: "default", mono: true, keyboard: .decimalPad)
                    FetchTextRow(label: "Seed time (min)", text: $seedTime, prompt: "default", mono: true, keyboard: .numberPad)
                }
            }
            Section {
                HStack(spacing: 10) {
                    Button("Test") { runTest() }
                        .buttonStyle(.web())
                        .disabled(!valid || busy || testing)
                    FetchTestResultLine(testing: testing, result: result)
                    Spacer(minLength: 0)
                }
            }
            .listRowBackground(Theme.card)
        }
        .onChange(of: baseUrl) { resetGate() }
        .onChange(of: apiPath) { resetGate() }
        .onChange(of: apiKey) { resetGate() }
        .onChange(of: proto) { resetGate() }
    }

    /// Any connection-affecting edit clears a stale test result / block.
    private func resetGate() {
        blocked = false
        result = nil
    }

    private func parseCategories(_ raw: String) -> [Int] {
        var seen = Set<Int>()
        return raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && seen.insert($0).inserted }
    }

    private var dailyCapValue: SettingsJSON {
        guard let n = Double(t(dailyCap)), n >= 0 else { return .null }
        return .int(Int(n.rounded()))
    }

    private func common() -> [String: SettingsJSON] {
        [
            "name": .string(t(name)),
            "protocol": .string(proto),
            "base_url": .string(t(baseUrl)),
            "api_path": .string(t(apiPath).isEmpty ? "/api" : t(apiPath)),
            "categories": .ints(parseCategories(categories)),
            "anime_categories": .ints(parseCategories(animeCategories)),
            "anime_standard_format_search": .bool(animeStandardFormat),
            "enabled_search": .bool(masterEnabled && enabledSearch),
            "enabled_rss": .bool(masterEnabled && enabledRss),
            "priority": .int(Int(t(priority)) ?? 0),
            "min_query_interval_seconds": .int(Int(t(minInterval)) ?? 0),
            "minimum_age_minutes": .int(Int(t(minimumAge)) ?? 0),
            "discovery_probe_unlimited": .bool(probeUnlimited),
            "discovery_daily_query_cap": dailyCapValue,
        ]
    }

    private func createBody() -> SettingsJSON {
        var b = common()
        b["api_key"] = .string(t(apiKey))
        return .object(b)
    }

    private func updateBody() -> SettingsJSON {
        var b = common()
        b["kind_scope_override"] = scopeOverride.isEmpty ? .null : .string(scopeOverride)
        if !t(apiKey).isEmpty { b["api_key"] = .string(t(apiKey)) }
        return .object(b)
    }

    private func runTest() {
        guard let client = model.client else { return }
        blocked = false
        testing = true
        Task {
            do { result = try await client.configTestUnsaved(.searchIndexers, createBody()) } catch {
                result = ConnectionTestResult(ok: false, message: error.settingsMessage)
            }
            testing = false
        }
    }

    private func commit(skipTest: Bool) async {
        guard let client = model.client else { return }
        let query = skipTest ? [URLQueryItem(name: "skip_test", value: "true")] : []
        do {
            if let indexer {
                try await client.configUpdate(.searchIndexers, id: indexer.id, updateBody(), query: query)
            } else {
                try await client.configCreate(.searchIndexers, createBody(), query: query)
            }
            await onSaved()
            dismiss()
        } catch {
            // The backend's validate-on-save gate 400s an enabled indexer whose
            // live test fails; that hard-blocks the write (no bypass).
            result = ConnectionTestResult(ok: false, message: error.settingsMessage)
            if case .http(400, _)? = error as? APIError { blocked = true }
        }
    }

    private func save() {
        guard valid, !blocked, let client = model.client else { return }
        busy = true
        Task {
            if !masterEnabled {
                await commit(skipTest: true)
            } else if !t(apiKey).isEmpty {
                // Master on with a key in hand: test in the form first, hard-block on failure.
                do {
                    let r = try await client.configTestUnsaved(.searchIndexers, createBody())
                    result = r
                    if r.ok { await commit(skipTest: true) } else { blocked = true }
                } catch {
                    result = ConnectionTestResult(ok: false, message: error.settingsMessage)
                    blocked = true
                }
            } else {
                await commit(skipTest: false)
            }
            busy = false
        }
    }
}
