import SwiftUI
import FusionhaKit

/// The v2 interactive search (mock browse-sheets.js `isBody`) on v1's
/// `InteractiveSearchModel`: the HD | 4K switch with the version's profile
/// and cutoff, v1's scope status and cooldown strips, the scan card
/// (releases, indexers, accepted), v1's passed-over chips, the title filter
/// and one Filters menu, then a W1 card per release. Grab anyway never
/// grabs straight away: it opens the decision (`V2GrabAnywaySheet`).
/// `embedded` drops the scroll view for the episode page's Search tab.
struct V2InteractiveSearchPane: View {
    @Bindable var model: InteractiveSearchModel
    var embedded = false
    @Environment(\.detailReduceMotion) private var reduce
    @Environment(AppModel.self) private var app
    @State private var deciding: ReleasePreview?
    /// "Block <GROUP>" from a card's ⋯: its own sheet over the search.
    @State private var blocking: GroupBlockTarget?

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                ScrollView {
                    content
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.immediately)
                .overlay(alignment: .bottom) { toast }
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
        // Filters reset per version (not on the first scoping from 0), as in v1.
        .onChange(of: model.editionId) { old, _ in if old != 0 { model.filters = ReleaseFilters() } }
        .sheet(item: $deciding) { release in
            V2GrabAnywaySheet(release: release, model: model)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $blocking) { target in
            V2BlockGroupSheet(target: target, title: model.store.detail?.title ?? "this title") {
                model.toast = SearchToast(text: $0)
            }
            .environment(model.store)
        }
        .task {
            if app.mayBlockGroups, model.store.groupBlocks == nil { await model.store.loadGroupBlocks() }
        }
    }

    /// Where the card's group is blocked: the loaded blocks, or the server's
    /// own rejection ("Release group X is blocked everywhere").
    private func groupBlockLabel(_ release: ReleasePreview) -> String? {
        if let block = model.store.groupBlock(for: release.releaseGroup) { return TitleGroupBlocks.scopeLabel(block) }
        guard release.rejected, TitleGroupBlocks.isGroupBlockReason(release.reason) else { return nil }
        return release.reason?.lowercased().hasSuffix("everywhere") == true ? "Everywhere" : "This title"
    }

    @ViewBuilder
    private var toast: some View {
        if let toast = model.toast {
            SearchToastView(text: toast.text)
                .padding(.bottom, 22)
                .transition(reduce ? .opacity : .opacity.combined(with: .offset(y: 12)))
                .id(toast.id)
        }
    }

    private var content: some View {
        let rows = model.rows
        let scanning = model.scanning
        let failed = model.failed
        let visible = scanning ? [] : model.filters.apply(rows)
        let current = currentFileName
        return VStack(alignment: .leading, spacing: 12) {
            if embedded { toast }
            V2SearchVersionRow(model: model)
            if let status = model.scopeStatus[model.editionId] { ScopeStatusStrip(status: status) }
            if !model.cooldown.isEmpty { CooldownNotice(indexers: model.cooldown) }
            V2SearchScanCard(model: model, rows: rows, scanning: scanning, failed: failed)
            SkipReasonChips(groups: model.skipGroups[model.editionId] ?? []) { model.store.viewTrail() }
            if !scanning && !failed && !rows.isEmpty {
                if rows.allSatisfy({ ($0.cfScore ?? 0) == 0 }) { SearchCFWarning() }
                V2ReleaseFilterRow(rows: rows, filters: $model.filters)
                LazyVStack(spacing: 10) {
                    ForEach(visible) { release in
                        V2ReleaseCard(release: release, downloading: model.grabbed.contains(release.guid),
                                      blocklistReason: blocklistReason(release),
                                      currentTier: current != nil && release.title == current ? model.edition?.tier : nil,
                                      groupBlock: groupBlockLabel(release),
                                      blockGroup: { blocking = GroupBlockTarget(group: $0) }) {
                            if release.rejected || release.blocklisted == true {
                                deciding = release
                            } else {
                                Task { await model.grab(release) }
                            }
                        }
                        .id(release.guid)
                    }
                }
                if visible.isEmpty { SearchNote(text: "No releases match these filters.") }
            }
        }
    }

    /// The release name of the shown version's file (the episode's when the
    /// search is for one), so its card is marked as the current file.
    private var currentFileName: String? {
        guard let edition = model.edition else { return nil }
        if let episodeId = model.target.episodeId {
            let episode = model.store.detail?.seasons?.flatMap(\.episodes).first(where: { $0.id == episodeId })
            return episode?.file(for: edition.id)?.sceneName
        }
        return edition.movieFile?.sceneName
    }

    private func blocklistReason(_ release: ReleasePreview) -> String {
        let subtitle = model.target.subtitle
        return release.blocklistReason ?? "Blocklisted: failed on \(subtitle.isEmpty ? "this" : "the \(subtitle)") version"
    }
}

/// HD | 4K with the shown version's profile and cutoff (mock "UHD-Movies ·
/// cutoff Remux-2160p").
private struct V2SearchVersionRow: View {
    let model: InteractiveSearchModel

    var body: some View {
        HStack(spacing: 10) {
            if model.editions.count > 1 {
                Picker("Version", selection: Binding(get: { model.editionId }, set: { model.selectEdition($0) })) {
                    ForEach(model.editions) { edition in
                        Text(edition.versionKey.isEmpty ? edition.tier.badgeLetters : edition.label).tag(edition.id)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            Text(profileLine)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var profileLine: String {
        guard let edition = model.edition else { return "" }
        var parts: [String] = []
        let name = model.store.profileName(edition.qualityProfileId)
        if name != "—" { parts.append(name) }
        if let cutoff = model.store.cutoff(edition.qualityProfileId) { parts.append("cutoff \(cutoff)") }
        return parts.joined(separator: " · ")
    }
}

/// "1,204 releases from 11 indexers · 0 accepted", or the scan, the
/// failure or the empty result (v1's `SearchScanBanner` messages).
private struct V2SearchScanCard: View {
    let model: InteractiveSearchModel
    let rows: [ReleasePreview]
    let scanning: Bool
    let failed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if scanning { ProgressView().controlSize(.small) } else {
                    Image(systemName: failed ? "exclamationmark.triangle" : "magnifyingglass")
                        .font(.system(size: 17))
                        .foregroundStyle(failed ? Theme.stuck : Theme.accentText)
                }
            }
            .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                if let sub { Text(sub).font(.system(size: 12.5)).foregroundStyle(Theme.mut) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            // Kit `.scan`: the accent at 10% over the W1 card, a 28% accent ring.
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            ZStack {
                ModuleSurface(radius: 16)
                shape.fill(Theme.i1.opacity(0.10))
                shape.strokeBorder(Theme.i1.opacity(0.28), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var integrationsOff: Bool { model.store.settings?.realIntegrations == false }

    private var title: String {
        if scanning { return "Searching indexers…" }
        if failed { return "Search failed" }
        if rows.isEmpty { return integrationsOff ? "Real integrations are disabled" : "No releases found" }
        let indexers = Set(rows.map(ReleaseSearch.indexer)).count
        let accepted = rows.filter { !$0.rejected && $0.blocklisted != true }.count
        return "\(rows.count) release\(rows.count == 1 ? "" : "s") from \(indexers) indexer\(indexers == 1 ? "" : "s") · \(accepted) accepted"
    }

    private var sub: String? {
        if scanning { return nil }
        if failed { return model.failures[model.editionId] ?? "Try again." }
        if rows.isEmpty { return integrationsOff ? "Enable them in Settings to search indexers." : "Try again later, or widen the profile." }
        return "Ranked by custom-format score. Each card says why it was passed over."
    }
}
