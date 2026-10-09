import SwiftUI
import FusionhaKit

/// Interactive ("Manual") search — the web's InteractiveSearchModal +
/// InteractiveSearch on a phone: the auto-search status strips, the HD/4K
/// edition toggle with its "Searched" strip, the scan banner, the filter row
/// (title, resolution, protocol, indexer, sort, direction, hide toggles) and one
/// card per release (title + group, quality/flags/size/age/indexer/seeders, the
/// rejection or blocklist reason, the signed custom-format score and an
/// icon-only Grab tile).
struct InteractiveSearchSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.detailReduceMotion) private var reduce
    let target: InteractiveTarget

    @State private var editionId = 0
    @State private var results: [Int: [ReleasePreview]] = [:]
    @State private var failures: [Int: String] = [:]
    @State private var inFlight: Set<Int> = []
    @State private var searchedAt: [Int: Date] = [:]
    @State private var scopeStatus: [Int: ReleaseScopeStatus] = [:]
    @State private var cooldown: [IndexerUnavailable] = []

    @State private var filters = ReleaseFilters()

    @State private var grabbed: Set<String> = []
    @State private var triggers: [String: String] = [:]
    @State private var toast: SearchToast?
    @State private var grabSuccess = 0
    @State private var started = false

    /// Every edition of the item: the toggle (web passes them all, so a scoped
    /// search can still flip HD ↔ 4K).
    private var editions: [DetailEdition] { store.detail?.orderedEditions ?? [] }
    private var edition: DetailEdition? { editions.first { $0.id == editionId } }
    private var heading: String {
        guard let title = store.detail?.title else { return target.subtitle }
        return target.subtitle.isEmpty ? title : "\(title) · \(target.subtitle)"
    }

    var body: some View {
        let rows = results[editionId] ?? []
        let scanning = inFlight.contains(editionId) || (results[editionId] == nil && failures[editionId] == nil)
        let failed = !scanning && failures[editionId] != nil
        let integrationsOff = store.settings?.realIntegrations == false
        let visible = scanning ? [] : filters.apply(rows)
        let showSeed = rows.contains(where: ReleaseSearch.isTorrent)
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let status = scopeStatus[editionId] { ScopeStatusStrip(status: status) }
                        if !cooldown.isEmpty { CooldownNotice(indexers: cooldown) }
                        if editions.count > 1 {
                            editionRow
                            searchedStrip
                        }
                        SearchScanBanner(scanning: scanning, chips: Set(rows.map(ReleaseSearch.indexer)).count,
                                   message: scanMessage(scanning: scanning, failed: failed, count: rows.count,
                                                        integrationsOff: integrationsOff))
                        if failed, let reason = failures[editionId] { SearchNote(text: reason) }
                        if !scanning && !failed && !rows.isEmpty {
                            if rows.allSatisfy({ ($0.cfScore ?? 0) == 0 }) { SearchCFWarning() }
                            ReleaseFilterBar(rows: rows, filters: $filters, reduce: reduce)
                            LazyVStack(spacing: 9) {
                                ForEach(visible) { release in
                                    card(release, showSeed: showSeed)
                                        .id(release.guid)
                                }
                            }
                            if visible.isEmpty { SearchNote(text: "No releases match these filters.") }
                        }
                        if !scanning && !failed && rows.isEmpty {
                            if integrationsOff {
                                Text("Real integrations are disabled — enable them in Settings to search indexers.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.txt)
                                    .lineSpacing(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .panel(Theme.panel2, radius: Theme.radius)
                                    .padding(.top, 14)
                            } else {
                                SearchNote(text: "No releases found for this search.")
                            }
                        }
                        SearchNote(text: "Wondering why a release scored the way it did? Open the Custom Format Tester.")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.immediately)
                .task(id: screenshotAnchor(visible)) {
                    guard let anchor = screenshotAnchor(visible) else { return }
                    try? await Task.sleep(for: .seconds(0.4))
                    proxy.scrollTo(anchor, anchor: .top)
                }
            }
            .background(Theme.panel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { header }
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: "Close") { dismiss() }
                }
                if editions.count <= 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Refresh", systemImage: "arrow.clockwise") { Task { await refresh() } }
                            .disabled(inFlight.contains(editionId))
                            .accessibilityLabel("Refresh \(edition?.label ?? "search") results")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    SearchToastView(text: toast.text)
                        .padding(.bottom, 22)
                        .transition(reduce ? .opacity : .opacity.combined(with: .offset(y: 12)))
                        .id(toast.id)
                }
            }
            .animation(reduce ? nil : .easeOut(duration: 0.2), value: toast)
        }
        .sensoryFeedback(.success, trigger: grabSuccess)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .task { await start() }
        .task(id: editionId) { await loadScopeStatus() }
        .task(id: toast?.id) {
            guard toast != nil else { return }
            do { try await Task.sleep(for: .seconds(2.6)) } catch { return }
            toast = nil
        }
        // Filters reset per edition (not on the first scoping from 0).
        .onChange(of: editionId) { old, _ in if old != 0 { filters = ReleaseFilters() } }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.grab)
                .frame(width: 30, height: 30)
                .background(Theme.grab.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Manual search").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                Text(heading)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Edition toggle + Searched strip

    private var editionRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(editions) { ed in
                    let active = ed.id == editionId
                    Button { selectEdition(ed.id) } label: {
                        HStack(spacing: 5) {
                            Text(ed.label)
                            if searchedAt[ed.id] != nil {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(active ? DetailTokens.badgeText : Theme.done)
                            }
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(active ? Theme.i2.mix(0.45, Theme.txt) : Theme.mut)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            if active {
                                Capsule().fill(Theme.i1.opacity(0.14))
                                    .overlay(Capsule().strokeBorder(Theme.i1.opacity(0.5)))
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(4)
            .glassEffect(.regular, in: Capsule())
            Button { Task { await refresh() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .detailSpinIf(inFlight.contains(editionId) && results[editionId] != nil)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(inFlight.contains(editionId))
            .accessibilityLabel("Refresh \(edition?.label ?? "search") results")
        }
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private var searchedStrip: some View {
        FlowRow(spacing: 8, lineSpacing: 6) {
            Text("Searched:").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.txt)
            ForEach(editions) { ed in
                let at = searchedAt[ed.id]
                HStack(spacing: 6) {
                    Text(at != nil ? "\(ed.label) ✓" : "\(ed.label) — not queried")
                    if let at {
                        Text(at.formatted(date: .omitted, time: .shortened))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .opacity(0.85)
                    }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(at != nil ? Theme.done : Theme.mut)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(at != nil ? Theme.done.opacity(0.16) : Color.white.opacity(0.05), in: Capsule())
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: Rows

    private func card(_ release: ReleasePreview, showSeed: Bool) -> ReleaseCard {
        let siblings = editions.map { (id: $0.id, label: $0.label, tier: $0.tier) }
        return ReleaseCard(
            release: release,
            showSeed: showSeed,
            downloading: grabbed.contains(release.guid),
            trigger: triggers[release.guid],
            autoTarget: ReleaseSearch.autoTarget(release.quality, activeTier: edition?.tier, editions: siblings),
            blocklistReason: release.blocklistReason
                ?? "blocklisted — failed on \(target.subtitle.isEmpty ? "this" : "the \(target.subtitle)") version"
        ) { Task { await grab(release) } }
    }

    private func scanMessage(scanning: Bool, failed: Bool, count: Int, integrationsOff: Bool) -> String {
        if scanning { return "querying indexers…" }
        if failed { return "Search failed — try again." }
        if count == 0 && integrationsOff { return "real integrations are disabled" }
        return "\(count) \(count == 1 ? "release" : "releases") · ranked by custom-format score"
    }

    // MARK: Loading

    private func start() async {
        guard !started else { return }
        started = true
        let first = target.editionIds.first ?? editions.first?.id ?? 0
        editionId = first
        // "All versions" chosen → every version is searched up front (the web's searchBoth).
        var seed = target.editionIds.count > 1 ? target.editionIds : [first]
        applyScreenshotState()
        if !seed.contains(editionId) { seed.append(editionId) }
        let now = Date()
        for id in seed { searchedAt[id] = now }
        for id in seed where id != editionId { Task { await load(id) } }
        Task { await loadCooldown() }
        await load(editionId)
    }

    private func selectEdition(_ id: Int) {
        guard id != editionId else { return }
        editionId = id
        if searchedAt[id] == nil { searchedAt[id] = Date() }
        if results[id] == nil && !inFlight.contains(id) { Task { await load(id) } }
    }

    private func refresh() async {
        await load(editionId)
        searchedAt[editionId] = Date()
    }

    private func load(_ id: Int) async {
        guard let client = store.client, id != 0, !inFlight.contains(id) else { return }
        #if DEBUG
        if screenshotView == "loading" { return }
        #endif
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        do {
            let releases = try await client.releases(itemId: store.itemId, editionId: id,
                                                      episodeId: target.episodeId, seasonNumber: target.seasonNumber)
            failures[id] = nil
            results[id] = releases
            #if DEBUG
            if screenshotView == "grabbed", id == editionId, let first = filters.apply(releases).first {
                await grab(first)
            }
            #endif
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            failures[id] = Self.describe(error)
        }
    }

    private func loadScopeStatus() async {
        guard let client = store.client, editionId != 0 else { return }
        if let status = try? await client.releaseScopeStatus(itemId: store.itemId, editionId: editionId,
                                                              episodeId: target.episodeId, seasonNumber: target.seasonNumber) {
            scopeStatus[editionId] = status
        }
    }

    private func loadCooldown() async {
        guard let client = store.client else { return }
        cooldown = (try? await client.unavailableIndexers())?.items ?? []
    }

    /// A short, readable cause under the failure banner.
    private static func describe(_ error: Error) -> String {
        if let url = error as? URLError {
            return url.code == .timedOut ? "The indexers took too long to answer." : url.localizedDescription
        }
        if case APIError.http(let status, _) = error {
            return detail(error) ?? "The server answered HTTP \(status)."
        }
        if error is DecodingError { return "The server's answer couldn't be read." }
        return error.localizedDescription
    }

    /// The backend's `detail` message on an HTTP error, if it sent one.
    private static func detail(_ error: Error) -> String? {
        guard case APIError.http(_, let body) = error,
              let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] else { return nil }
        return json["detail"] as? String
    }

    // MARK: Grab

    /// Optimistic like the web: the row flips to Downloading at once, a real
    /// failure reverts it (unless the server says it's already downloading).
    /// A blocklisted release grabs with the override that lifts the blocklist.
    private func grab(_ release: ReleasePreview) async {
        guard let client = store.client, !grabbed.contains(release.guid) else { return }
        let guid = release.guid
        let override = release.blocklisted == true
        grabbed.insert(guid)
        triggers[guid] = override ? "forced" : "interactive"
        do {
            let response = try await client.grab(itemId: store.itemId, ReleaseGrabRequest(
                release: release, editionId: editionId, episodeId: target.episodeId,
                seasonNumber: target.seasonNumber, override: override))
            if let trigger = response.grabTrigger { triggers[guid] = trigger }
            grabSuccess += 1
            toast = SearchToast(text: override ? "Grabbed anyway — removed from blocklist" : "Sent to download client")
            await store.reload()
        } catch {
            let message = Self.detail(error)
            let inFlightAlready = message?.range(of: "already (downloading|grabbed)", options: [.regularExpression, .caseInsensitive]) != nil
            if !inFlightAlready {
                grabbed.remove(guid)
                triggers[guid] = nil
            }
            toast = SearchToast(text: message ?? "Grab failed")
        }
    }

    // MARK: Screenshots

    #if DEBUG
    private var screenshotView: String? { ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SEARCH_VIEW"] }
    #endif

    private func applyScreenshotState() {
        #if DEBUG
        switch screenshotView {
        case "4k":
            if let uhd = editions.first(where: { $0.tier == .uhd }) { editionId = uhd.id }
        case "rejected": filters.hideRejected = false
        case "nomatch": filters.keyword = "director's cut"
        default: break
        }
        #endif
    }

    private func screenshotAnchor(_ visible: [ReleasePreview]) -> String? {
        #if DEBUG
        guard screenshotView == "rejected" else { return nil }
        return visible.first(where: \.rejected)?.guid
        #else
        return nil
        #endif
    }
}
