import SwiftUI
import FusionhaKit

/// Interactive ("Manual") search — the web's InteractiveSearchModal on a phone:
/// a sheet around the shared InteractiveSearchPane.
struct InteractiveSearchSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: InteractiveTarget
    @State private var model: InteractiveSearchModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model { InteractiveSearchPane(model: model) } else { Theme.panel }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { header }
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: "Close") { dismiss() }
                }
                if let model, model.editions.count <= 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                            .disabled(model.inFlight.contains(model.editionId))
                            .accessibilityLabel("Refresh \(model.edition?.label ?? "search") results")
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .onAppear {
            if model == nil { model = InteractiveSearchModel(store: store, target: target) }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.grab)
                .frame(width: 30, height: 30)
                .background(Theme.grab.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Manual search").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                Text(model?.heading ?? target.subtitle)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// InteractiveSearch.tsx: the auto-search status strips, the HD/4K edition
/// toggle with its "Searched" strip, the scan banner, the filter row and one
/// card per release (title + group, quality/flags/size/age/indexer/seeders, the
/// rejection or blocklist reason, the signed custom-format score and an
/// icon-only Grab tile).
struct InteractiveSearchPane: View {
    @Bindable var model: InteractiveSearchModel
    @Environment(\.detailReduceMotion) private var reduce

    var body: some View {
        let rows = model.rows
        let scanning = model.scanning
        let failed = model.failed
        let integrationsOff = model.store.settings?.realIntegrations == false
        let visible = scanning ? [] : model.filters.apply(rows)
        let showSeed = rows.contains(where: ReleaseSearch.isTorrent)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let status = model.scopeStatus[model.editionId] { ScopeStatusStrip(status: status) }
                    if !model.cooldown.isEmpty { CooldownNotice(indexers: model.cooldown) }
                    SkipReasonChips(groups: model.skipGroups[model.editionId] ?? []) { model.store.viewTrail() }
                    if model.editions.count > 1 {
                        SearchEditionToggle(model: model)
                        SearchedStrip(model: model)
                    }
                    SearchScanBanner(scanning: scanning, chips: Set(rows.map(ReleaseSearch.indexer)).count,
                                     message: scanMessage(scanning: scanning, failed: failed, count: rows.count,
                                                          integrationsOff: integrationsOff))
                    if failed, let reason = model.failures[model.editionId] { SearchNote(text: reason) }
                    if !scanning && !failed && !rows.isEmpty {
                        if rows.allSatisfy({ ($0.cfScore ?? 0) == 0 }) { SearchCFWarning() }
                        ReleaseFilterBar(rows: rows, filters: $model.filters, reduce: reduce)
                        LazyVStack(spacing: 9) {
                            ForEach(visible) { release in
                                card(release, showSeed: showSeed).id(release.guid)
                            }
                        }
                        if visible.isEmpty { SearchNote(text: "No releases match these filters.") }
                    }
                    if !scanning && !failed && rows.isEmpty {
                        if integrationsOff {
                            Text("Real integrations are disabled. Enable them in Settings to search indexers.")
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
            .task(id: model.screenshotAnchor(visible)) {
                guard let anchor = model.screenshotAnchor(visible) else { return }
                try? await Task.sleep(for: .seconds(0.4))
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        .background(Theme.panel)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                SearchToastView(text: toast.text)
                    .padding(.bottom, 22)
                    .transition(reduce ? .opacity : .opacity.combined(with: .offset(y: 12)))
                    .id(toast.id)
            }
        }
        .animation(reduce ? nil : .easeOut(duration: 0.2), value: model.toast)
        .sensoryFeedback(.success, trigger: model.grabSuccess)
        .task { await model.start() }
        .task(id: model.editionId) {
            await model.loadScopeStatus()
            await model.loadSkipReasons()
        }
        .task(id: model.toast?.id) {
            guard model.toast != nil else { return }
            do { try await Task.sleep(for: .seconds(2.6)) } catch { return }
            model.toast = nil
        }
        // Filters reset per edition (not on the first scoping from 0).
        .onChange(of: model.editionId) { old, _ in if old != 0 { model.filters = ReleaseFilters() } }
    }

    private func card(_ release: ReleasePreview, showSeed: Bool) -> ReleaseCard {
        let siblings = model.editions.map { (id: $0.id, label: $0.label, tier: $0.tier) }
        let subtitle = model.target.subtitle
        return ReleaseCard(
            release: release,
            showSeed: showSeed,
            downloading: model.grabbed.contains(release.guid),
            trigger: model.triggers[release.guid],
            autoTarget: ReleaseSearch.autoTarget(release.quality, activeTier: model.edition?.tier, editions: siblings),
            blocklistReason: release.blocklistReason
                ?? "blocklisted — failed on \(subtitle.isEmpty ? "this" : "the \(subtitle)") version"
        ) { Task { await model.grab(release) } }
    }

    private func scanMessage(scanning: Bool, failed: Bool, count: Int, integrationsOff: Bool) -> String {
        if scanning { return "querying indexers…" }
        if failed { return "Search failed — try again." }
        if count == 0 && integrationsOff { return "real integrations are disabled" }
        return "\(count) \(count == 1 ? "release" : "releases") · ranked by custom-format score"
    }
}

/// The HD/4K edition toggle with its refresh button.
private struct SearchEditionToggle: View {
    let model: InteractiveSearchModel

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(model.editions) { ed in
                    let active = ed.id == model.editionId
                    Button { model.selectEdition(ed.id) } label: {
                        HStack(spacing: 5) {
                            Text(ed.label)
                            if model.searchedAt[ed.id] != nil {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(active ? DetailTokens.badgeText : Theme.done)
                            }
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(active ? Theme.accentText : Theme.mut)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            if active { Capsule().fill(Theme.i1.opacity(0.14)) }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(4)
            .glassEffect(.regular, in: Capsule())
            Button { Task { await model.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .detailSpinIf(model.inFlight.contains(model.editionId) && model.results[model.editionId] != nil)
                    .frame(width: 22, height: 22)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(.horizontal, -11).padding(.vertical, -11)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(model.inFlight.contains(model.editionId))
            .accessibilityLabel("Refresh \(model.edition?.label ?? "search") results")
        }
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
}

/// "Searched: HD·1080p ✓ 14:02 · UHD·4K — not queried".
private struct SearchedStrip: View {
    let model: InteractiveSearchModel

    var body: some View {
        FlowRow(spacing: 8, lineSpacing: 6) {
            Text("Searched:").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.txt)
            ForEach(model.editions) { ed in
                let at = model.searchedAt[ed.id]
                HStack(spacing: 6) {
                    Text(at != nil ? "\(ed.label) ✓" : "\(ed.label) — not queried")
                    if let at {
                        Text(at.formatted(date: .omitted, time: .shortened))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .opacity(0.85)
                    }
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(at != nil ? Theme.done : Theme.mut)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(at != nil ? Theme.done.opacity(0.16) : Theme.txt.opacity(0.05), in: Capsule())
            }
        }
        .padding(.bottom, 8)
    }
}
