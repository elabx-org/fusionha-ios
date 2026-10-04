import SwiftUI
import FusionhaKit

/// Settings → Indexers (`IndexersPanel.tsx`): the range-driven fleet overview,
/// then every indexer as a performance card (enable switch, Test, edit, delete,
/// capability chips, share / yield / success / activity) with sort + protocol
/// filters, Test all, and the rich add/edit sheet with the validate-on-save gate.
struct IndexersPanel: View {
    @Environment(AppModel.self) private var model
    @State private var indexers: [SearchIndexerInfo] = []
    @State private var stats: IndexerStatsResponse?
    @State private var range: IndexerRange = .week
    @State private var loaded = false
    @State private var error: String?
    @State private var results: [Int: ConnectionTestResult] = [:]
    @State private var testing: Set<Int> = []
    @State private var testingAll = false
    @State private var sort: SortKey = .share
    @State private var protocolFilter = "ALL"
    @State private var editing: SearchIndexerInfo?
    @State private var adding = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    enum SortKey: String, CaseIterable, Identifiable {
        case share = "Share", byYield = "Yield", grabs = "Grabs", success = "Success", name = "Name"
        var id: String { rawValue }
    }

    private var metrics: [IndexerMetric] { IndexerMetric.build(indexers, stats: stats) }

    private var rows: [IndexerMetric] {
        let filtered = protocolFilter == "ALL" ? metrics : metrics.filter { $0.indexer.protocol == protocolFilter }
        return filtered.sorted { a, b in
            switch sort {
            case .byYield: return a.yieldValue > b.yieldValue
            case .grabs: return a.grabsRange > b.grabsRange
            case .success: return (a.successPct ?? -1) > (b.successPct ?? -1)
            case .name: return a.indexer.name.localizedCompare(b.indexer.name) == .orderedAscending
            case .share: return a.share > b.share
            }
        }
    }

    var body: some View {
        let all = metrics
        let maxShare = max(1, all.map(\.share).max() ?? 1)
        let maxYield = max(1, all.map(\.yieldValue).max() ?? 1)
        FetchingPage(slug: "indexers", toaster: toaster, confirm: $confirm, refresh: load) {
            IndexerFleetOverview(summary: stats?.summary, metrics: all, range: $range)
                .padding(.bottom, 22)

            toolbar.padding(.bottom, 12)

            if !loaded || error != nil { FetchLoading(error: error) }
            if loaded, indexers.isEmpty, error == nil {
                FetchEmpty(text: "No indexers yet — add a Newznab or Torznab indexer, or let Prowlarr sync them in.")
            }
            VStack(spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, metric in
                    IndexerCard(metric: metric, index: index, maxShare: maxShare, maxYield: maxYield,
                                result: results[metric.id], testing: testing.contains(metric.id),
                                onToggle: { toggle(metric.indexer, $0) },
                                onTest: { runTest(metric.indexer) },
                                onEdit: { editing = metric.indexer },
                                onDelete: { askDelete(metric.indexer) })
                        .fetchReveal(index)
                }
            }
        }
        .task { await load() }
        .task(id: range) { await loadStats() }
        .sheet(isPresented: $adding) {
            IndexerSheet(indexer: nil) { await load() }
        }
        .sheet(item: $editing) { indexer in
            IndexerSheet(indexer: indexer) { await load() }
        }
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All indexers").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer()
                Button(testingAll ? "Testing…" : "Test all") { runTestAll() }
                    .buttonStyle(.web(.ghost))
                    .disabled(indexers.isEmpty || testingAll)
                Button("+ Add indexer") { adding = true }.buttonStyle(.web())
            }
            HStack(spacing: 8) {
                Picker("Protocol", selection: $protocolFilter) {
                    Text("All").tag("ALL")
                    Text("Usenet").tag("USENET")
                    Text("Torrent").tag("TORRENT")
                }
                .pickerStyle(.segmented)
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(SortKey.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .tint(Theme.txt)
                .accessibilityLabel("Sort by \(sort.rawValue)")
            }
        }
    }

    // MARK: Actions

    private func load() async {
        guard let client = model.client else { return }
        do {
            indexers = try await client.configList(.searchIndexers)
            error = nil
        } catch {
            self.error = error.settingsMessage
        }
        loaded = true
        await loadStats()
    }

    private func loadStats() async {
        guard let client = model.client else { return }
        stats = try? await client.indexerStats(range: range.rawValue)
    }

    private func toggle(_ indexer: SearchIndexerInfo, _ on: Bool) {
        guard let client = model.client else { return }
        Task {
            do {
                try await client.configUpdate(.searchIndexers, id: indexer.id,
                                              ["enabled_search": .bool(on), "enabled_rss": .bool(on)])
                await load()
            } catch {
                toaster.error(error, title: "Could not update \(indexer.displayName)")
            }
        }
    }

    private func runTest(_ indexer: SearchIndexerInfo) {
        guard let client = model.client else { return }
        testing.insert(indexer.id)
        Task {
            do {
                let r = try await client.configTest(.searchIndexers, id: indexer.id)
                results[indexer.id] = r
                if r.ok { await loadStats() }
            } catch {
                results[indexer.id] = ConnectionTestResult(ok: false, message: error.settingsMessage)
            }
            testing.remove(indexer.id)
        }
    }

    /// arr's "Test All Indexers": every enabled indexer at once, one roll-up toast.
    private func runTestAll() {
        guard let client = model.client else { return }
        testingAll = true
        Task {
            do {
                let res = try await client.testAllIndexers()
                for r in res.results { results[r.id] = ConnectionTestResult(ok: r.ok, message: r.message) }
                if res.results.contains(where: \.ok) { await loadStats() }
                let passed = res.results.filter(\.ok).count
                toaster.show("\(passed) of \(res.results.count) passed", title: "Indexers tested",
                             tone: passed == res.results.count ? .success : .warning)
            } catch {
                toaster.show(error.settingsMessage, tone: .error)
            }
            testingAll = false
        }
    }

    private func askDelete(_ indexer: SearchIndexerInfo) {
        confirm = FetchConfirm(title: "Delete \(indexer.displayName)?",
                               message: indexer.source == "prowlarr"
                                ? "Prowlarr may sync it back on its next run."
                                : "fusionha stops searching this indexer.") {
            Task {
                guard let client = model.client else { return }
                do {
                    try await client.configDelete(.searchIndexers, id: indexer.id)
                    await load()
                } catch { toaster.error(error, title: "Could not delete the indexer") }
            }
        }
    }
}

// MARK: Card

private let capChips: [(String, String)] = [("tv", "TV"), ("movie", "Movies"), ("anime", "Anime"), ("id_search", "id-search")]

private func kindScopeLabel(_ scope: String) -> String {
    switch scope {
    case "anime": return "Anime only"
    case "non_anime": return "Non-anime"
    default: return "All series"
    }
}

private struct IndexerCard: View {
    let metric: IndexerMetric
    let index: Int
    let maxShare: Double
    let maxYield: Double
    let result: ConnectionTestResult?
    let testing: Bool
    let onToggle: (Bool) -> Void
    let onTest: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var indexer: SearchIndexerInfo { metric.indexer }
    private var stateColor: Color {
        metric.state == "backoff" ? Theme.miss : metric.state == "disabled" ? Theme.dim : Theme.done
    }
    private var sparkColor: Color {
        metric.state == "backoff" ? Theme.miss : metric.state == "disabled" ? Theme.dim : Theme.grab
    }
    private var delay: Double { Double(min(index, 10)) * 0.045 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            top
            metricsGrid
            mixRow
            if metric.state == "backoff" { backoffStrip }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [stateColor.opacity(0.10), stateColor.opacity(0)], startPoint: .leading, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(metric.state == "backoff" ? Theme.miss.opacity(0.35) : Theme.line))
        .opacity(metric.state == "disabled" ? 0.72 : 1)
    }

    private var top: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(stateColor).frame(width: 8, height: 8)
                    .background(Circle().fill(stateColor.opacity(0.18)).padding(-3))
                    .padding(.top, 6)
                FetchFlow(spacing: 6, lineSpacing: 5) {
                    Text(indexer.displayName).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if indexer.source == "prowlarr" {
                        Text("P")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color(hex: 0xE66001), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .accessibilityLabel("Synced from Prowlarr")
                    }
                    let tint = indexer.isTorrent ? Theme.grab : Theme.indigo
                    Text(indexer.isTorrent ? "TORRENT" : "USENET")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(tint.opacity(0.4)))
                    Text("· pri \(indexer.priority)").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.dim)
                    if metric.isNew { FetchChip(text: "NEW", color: Theme.done, border: Theme.done.opacity(0.32), size: 8.5) }
                    if testing {
                        ProgressView().controlSize(.mini)
                    } else if let result {
                        FetchPill(text: result.ok ? "Connected" : "Failed", tone: result.ok ? .ok : .err)
                    }
                }
            }
            FetchFlow(spacing: 5, lineSpacing: 5) {
                ForEach(capChips, id: \.0) { key, label in
                    let on = capOn(key)
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(on ? Theme.txt : Theme.mut)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(on ? Theme.panel2 : .clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line))
                }
                let scope = indexer.effectiveKindScope
                if scope != "all" {
                    Text(kindScopeLabel(scope) + (indexer.kindScopeOverride?.isEmpty == false ? " (manual)" : ""))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.panel2, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line))
                }
            }
            if let result, !result.ok {
                Text(result.message).font(.system(size: 11.5)).foregroundStyle(Theme.danger).lineLimit(3)
            }
            HStack(spacing: 4) {
                if metric.state == "backoff" {
                    Text("backoff")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Theme.miss)
                        .padding(.horizontal, 9).padding(.vertical, 2)
                        .background(Theme.miss.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.miss.opacity(0.3)))
                }
                Spacer()
                Toggle("Enable \(indexer.displayName)", isOn: Binding(get: { indexer.isEnabled }, set: onToggle))
                    .labelsHidden()
                    .tint(Theme.indigo)
                FetchIconButton(systemName: "bolt", label: "Test \(indexer.displayName)", action: onTest)
                    .disabled(testing)
                FetchIconButton(systemName: "pencil", label: "Edit \(indexer.displayName)", action: onEdit)
                FetchIconButton(systemName: "trash", label: "Delete \(indexer.displayName)", danger: true, action: onDelete)
            }
        }
    }

    private func capOn(_ key: String) -> Bool {
        let caps = metric.stat?.caps
        switch key {
        case "tv": return caps?.tv == true
        case "movie": return caps?.movie == true
        case "anime": return caps?.anime == true
        default: return caps?.idSearch == true
        }
    }

    private var metricsGrid: some View {
        let lowYield = maxYield > 0 ? metric.yieldValue <= maxYield * 0.25 : true
        return Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 14) {
            GridRow(alignment: .bottom) {
                cell("Grabs") {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(FetchFormat.grouped(metric.grabsRange)).metricValue()
                        if metric.grabs24h > 0 {
                            Text("▲\(metric.grabs24h)").font(.system(size: 10.5, weight: .bold)).foregroundStyle(Theme.done)
                        }
                    }
                    Text(metric.grabs24h > 0 ? "\(metric.grabs24h) in 24h" : "none in 24h").metricSub()
                }
                cell("Grab share") {
                    Text(verbatim: String(format: "%.1f%%", metric.share)).metricValue()
                    FetchBar(fraction: metric.share / maxShare, color: Theme.indigo, height: 5, delay: delay + 0.12)
                }
                cell("Activity") {
                    IndexerSparkline(values: metric.activity, color: sparkColor, delay: delay).frame(height: 34)
                }
            }
            GridRow(alignment: .bottom) {
                cell("Yield") {
                    (Text("\(Int(metric.yieldValue.rounded()))") + Text("/100 q").font(.system(size: 10)).foregroundColor(Theme.mut))
                        .metricValue()
                    FetchBar(fraction: metric.yieldValue / maxYield, color: lowYield ? Theme.miss : Theme.done,
                             height: 5, delay: delay + 0.18)
                }
                cell("Success") {
                    Text(metric.successPct.map { "\($0)%" } ?? "—")
                        .metricValue(color: metric.successPct == nil ? Theme.dim : (metric.successPct ?? 100) < 100 ? Theme.miss : Theme.txt)
                    Text("7-day").metricSub()
                }
                cell("Last used") {
                    Text(metric.stat?.lastUsedAt.map { FetchFormat.ago($0) } ?? "—")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                }
            }
        }
    }

    private func cell<C: View>(_ key: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mixRow: some View {
        let cm = metric.stat?.contentMix
        let tm = metric.stat?.tierMix
        let movie = cm?.movie ?? 0, series = cm?.series ?? 0, anime = cm?.anime ?? 0
        let hd = tm?.hd ?? 0, uhd = tm?.uhd ?? 0
        let excl = metric.stat?.exclusive?.total ?? 0
        let early = metric.stat?.exclusive?.early
        return VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(Theme.line).frame(height: 1)
            mixGroup("Content", parts: [(Double(movie), Theme.indigo), (Double(series), Theme.cyan), (Double(anime), Theme.edition)],
                     legend: [("\(movie) film", Theme.indigo), ("\(series) tv", Theme.cyan), ("\(anime) anime", Theme.edition)])
            mixGroup("Tier", parts: [(Double(hd), Theme.premiere), (Double(uhd), Theme.cyan)],
                     legend: [("\(hd) HD", Theme.premiere), ("\(uhd) 4K", Theme.cyan)])
            VStack(alignment: .leading, spacing: 3) {
                mixKey("Exclusive")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(FetchFormat.grouped(excl)).font(.system(size: 15, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.edition)
                    Text("\(early.map { $0 > 0 ? "\($0) early · " : "" } ?? "")only this indexer had it")
                        .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                }
            }
        }
    }

    private func mixKey(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 9.5, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
    }

    private func mixGroup(_ key: String, parts: [(Double, Color)], legend: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            mixKey(key)
            IndexerSplitBar(parts: parts.allSatisfy { $0.0 == 0 } ? [(1, Color.white.opacity(0.06))] : parts, gap: 0)
                .frame(height: 6)
            HStack(spacing: 10) {
                ForEach(legend, id: \.0) { text, color in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 7)
                        Text(text).font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                    }
                }
            }
        }
    }

    private var backoffStrip: some View {
        let health = metric.stat?.health
        return HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 12))
            Text("\(health?.failureCount ?? 0) consecutive failures\(health?.lastFailureReason.map { " · \($0)" } ?? "")")
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            (Text("auto-") + Text(retryHint(health?.disabledTill)).bold())
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.miss)
        .padding(10)
        .background(Theme.miss.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func retryHint(_ till: String?) -> String {
        guard let date = FetchFormat.date(till) else { return "retrying" }
        let mins = Int((date.timeIntervalSinceNow / 60).rounded())
        if mins <= 0 { return "retrying" }
        if mins < 60 { return "retry in \(mins)m" }
        return "retry in \(Int((Double(mins) / 60).rounded()))h"
    }
}

private extension Text {
    func metricValue(color: Color = Theme.txt) -> some View {
        self.font(.system(size: 17, weight: .heavy).monospacedDigit()).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
    }
    func metricSub() -> some View {
        self.font(.system(size: 10.5)).foregroundStyle(Theme.mut).lineLimit(1)
    }
}

// MARK: Add / edit

/// The rich indexer dialog: master Enable, connection, categories, priority,
/// discovery budget, usenet age gate, series scope, the arr enable flags, torrent
/// seed criteria and an in-form Test. An enabled indexer must pass its test to save.
private struct IndexerSheet: View {
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
