import SwiftUI
import FusionhaKit

// The quality-editions switcher (EditionsSwitcher.tsx): the VERSION/CUT row,
// the ACT ON row with its tier pills, the fold, and the reveal container that
// picks the series/movie variant. Plus the per-edition rail, the search button
// with its result states, the search-mode menu and the flash strips.

struct EditionsSwitcher: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail

    private var canEdit: Bool { model.me?.can("edit") ?? true }

    var body: some View {
        let eff = store.effScope
        let tiers = detail.distinctTiers
        VStack(alignment: .leading, spacing: 9) {
            if detail.hasVersions {
                FlowRow(spacing: 9) {
                    DetailRowLabel(text: detail.isSeries ? "Version" : "Cut")
                    DetailScopePill(active: eff.version == "all", tint: Theme.anime, action: { selectVersion("all") }) {
                        Text("All versions")
                    }
                    ForEach(detail.versionKeys, id: \.self) { key in
                        DetailScopePill(active: eff.version == key, tint: Theme.anime, action: { selectVersion(key) }) {
                            Text(versionLabel(key))
                        }
                    }
                    if canEdit {
                        DetailAddChip(label: "version") {
                            store.addPreset = AddEditionPreset(tier: eff.tierValue ?? tiers.first, version: "")
                        }
                    }
                }
            }

            FlowRow(spacing: 9) {
                DetailRowLabel(text: "Act on")
                if tiers.count > 1 {
                    DetailScopePill(active: eff.tier == "all", action: { selectTier("all") }) {
                        Text("All")
                        if eff.tier == "all" { caret }
                    }
                }
                ForEach(tiers, id: \.self) { tier in
                    tierPill(tier, eff: eff)
                }
                if canEdit {
                    DetailAddChip(label: addLabel(tiers)) {
                        let missing = QualityTier.ordered.first { !tiers.contains($0) }
                        store.addPreset = AddEditionPreset(tier: detail.isSeries ? (missing ?? tiers.first) : nil, version: nil)
                    }
                }
            }

            if store.folded {
                Text(foldedHint(eff))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 3)
                    .transition(.opacity)
            } else {
                EditionReveal(detail: detail)
                    .padding(.top, 3)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: -8)), removal: .opacity))
            }
        }
        .detailAnimation(.snappy(duration: 0.32), value: store.folded)
        .detailAnimation(.snappy(duration: 0.32), value: store.scope)
    }

    private var caret: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .rotationEffect(.degrees(store.folded ? -90 : 0))
            .detailAnimation(.easeInOut(duration: 0.15), value: store.folded)
    }

    private func tierPill(_ tier: QualityTier, eff: DetailScope) -> some View {
        let active = eff.tier == tier.rawValue
        let edition = detail.edition(tier: tier, version: eff.version)
        return DetailScopePill(active: active, tint: DetailTokens.tier(tier), action: { selectTier(tier.rawValue) }) {
            DetailDot(color: edition.map { DetailTokens.dot(store.dot($0)) } ?? Theme.miss)
            Text(tier.chipLabel)
            Text(edition.map { detail.coverageText($0) } ?? (detail.isSeries ? "0/\(detail.allEpisodes.count)" : "0/1"))
                .font(.system(size: 11, design: .monospaced))
                .opacity(0.85)
            if active { caret }
        }
    }

    private func addLabel(_ tiers: [QualityTier]) -> String {
        guard detail.isSeries else { return "edition" }
        if let missing = QualityTier.ordered.first(where: { !tiers.contains($0) }) { return "\(missing.tierShort) edition" }
        return "tier"
    }

    private func foldedHint(_ eff: DetailScope) -> String {
        if let tier = eff.tierValue {
            return "Detail collapsed — the page stays scoped to \(tier.chipLabel). Tap \(tier.chipLabel) to reopen."
        }
        return "Detail collapsed — the page still acts on all editions. Tap All to reopen."
    }

    /// Re-tapping the active tier folds the reveal; any change re-opens it.
    private func selectTier(_ target: String) {
        let eff = store.effScope
        if eff.tier == target {
            store.folded.toggle()
        } else {
            store.scope = DetailScope(tier: target, version: eff.version)
        }
    }

    private func selectVersion(_ target: String) {
        let eff = store.effScope
        if eff.version == target {
            store.folded.toggle()
        } else {
            store.scope = DetailScope(tier: eff.tier, version: target)
        }
    }
}

/// The reveal container (`.reveal`): picks the variant for the scope.
struct EditionReveal: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail

    var body: some View {
        let eff = store.effScope
        let versionEditions = eff.version == "all" ? detail.orderedEditions
            : detail.orderedEditions.filter { $0.versionKey == eff.version }
        VStack(alignment: .leading, spacing: 0) {
            AttentionBanners(editions: store.scopedEditions)
            if let tier = eff.tierValue, let edition = detail.edition(tier: tier, version: eff.version) {
                if detail.isSeries {
                    ScopedSeriesReveal(detail: detail, edition: edition)
                } else {
                    ScopedMovieReveal(detail: detail, edition: edition)
                }
            } else if detail.isSeries {
                if eff.version == "all" && detail.hasVersions {
                    MatrixReveal(detail: detail)
                } else {
                    SeriesAllReveal(detail: detail, editions: versionEditions)
                }
            } else {
                MovieAllReveal(detail: detail, editions: versionEditions)
            }
        }
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
    }
}

/// The reveal header row (`rHead`): dot(s), label, count, state pill, then the rail.
struct RevealHeader<Dots: View>: View {
    let label: String
    var labelColor: Color = Theme.txt
    var count: String?
    var state: DetailStatePillKind?
    let detail: ItemDetail
    /// nil → the search-all rail; an edition → its per-edition rail; hidden when `showsRail` is false.
    var railEdition: DetailEdition?
    var showsRail = true
    @ViewBuilder var dots: Dots

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowRow(spacing: 12, lineSpacing: 8) {
                HStack(spacing: 8) {
                    dots
                    Text(label).font(.system(size: 15, weight: .heavy)).foregroundStyle(labelColor)
                }
                if let count {
                    Text(count).font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.mut)
                }
                if let state { DetailStatePill(kind: state) }
            }
            if showsRail {
                PerEditionRail(detail: detail, edition: railEdition)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }
}

// MARK: - Per-edition rail

/// PerEditionRail: Search (+ mode caret), Interactive, Edit — or one
/// "Search all monitored editions" magnifier at scope All.
struct PerEditionRail: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let edition: DetailEdition?

    private var canSearch: Bool { model.me?.can("search") ?? true }
    private var canEdit: Bool { model.me?.can("edit") ?? true }

    var body: some View {
        HStack(spacing: 4) {
            if let edition {
                if canSearch {
                    SearchActionButton(label: edition.label, editionId: edition.id)
                    Rectangle().fill(Theme.line).frame(width: 1, height: 18)
                    SearchModeMenu(detail: detail, edition: edition)
                    InteractiveSearchButton(detail: detail, edition: edition)
                }
                if canEdit {
                    DetailRailButton(systemImage: "pencil", label: "Edit \(edition.label)", size: 30, glyph: 15) {
                        store.showingEdit = true
                    }
                }
            } else if canSearch {
                SearchActionButton(label: "all editions", accessibility: "Search all monitored editions")
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
    }
}

/// SearchActionButton: idle → searching → ok / none / fail, then back to idle.
struct SearchActionButton: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    let label: String
    var editionId: Int?
    var season: Int?
    var episodeId: Int?
    var accessibility: String?
    var size: CGFloat = 30
    var glyph: CGFloat = 15
    var bordered = false

    private enum Phase { case idle, searching, ok, none, fail }
    @State private var phase: Phase = .idle
    @State private var shakes = 0
    @State private var popped = false

    var body: some View {
        Button(action: run) {
            ZStack {
                switch phase {
                case .idle:
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.mut)
                case .searching:
                    DetailSpinner(size: glyph, color: Theme.grab)
                case .ok:
                    Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Theme.done)
                case .none:
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.miss)
                case .fail:
                    Image(systemName: "xmark").fontWeight(.bold).foregroundStyle(Theme.danger)
                }
            }
            .font(.system(size: glyph))
            .scaleEffect(popped ? 1.2 : 1)
            .frame(width: size, height: size)
            .background {
                if bordered {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.panel2)
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DetailPressStyle())
        .disabled(phase == .searching)
        .detailShake(trigger: shakes)
        .sensoryFeedback(.success, trigger: popped) { _, new in new }
        .accessibilityLabel(accessibility ?? "Search \(label)")
    }

    private func run() {
        phase = .searching
        Task {
            let decisions = await store.search(label: label, editionId: editionId, season: season, episodeId: episodeId)
            if let decisions {
                if decisions.contains(where: \.grabbed) {
                    phase = .ok
                    if !reduce {
                        withAnimation(DetailMotion.pop) { popped = true }
                        try? await Task.sleep(for: .seconds(0.16))
                        withAnimation(DetailMotion.pop) { popped = false }
                    }
                } else {
                    phase = .none
                    shakes += 1
                }
            } else {
                phase = .fail
                shakes += 1
            }
            try? await Task.sleep(for: .seconds(2.2))
            phase = .idle
        }
    }
}

/// The split caret's SearchModeMenu.
struct SearchModeMenu: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let edition: DetailEdition

    var body: some View {
        Menu {
            Button {
                Task { await store.search(label: edition.label, editionId: edition.id) }
            } label: {
                Text("Search \(edition.label)")
                Text(detail.isSeries
                     ? "Every monitored season of this edition — pack-preferred, missing + upgrades."
                     : "This edition — missing + upgrades.")
            }
            if detail.isSeries {
                Button {
                    Task { await store.gradualSearch(label: edition.label, editionId: edition.id, missingOnly: true) }
                } label: {
                    Text("Search missing only")
                    Text("gradual · the gaps only, one at a time")
                }
                Button {
                    Task { await store.gradualSearch(label: edition.label, editionId: edition.id, missingOnly: false) }
                } label: {
                    Text("Search each episode")
                    Text("gradual · one at a time, ~\(store.seasonInterval)s apart")
                }
            } else {
                Button {
                    Task { await store.search(label: edition.label, editionId: edition.id, missingOnly: true) }
                } label: {
                    Text("Search missing only")
                    Text("Skip if this edition already has a file")
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.cyan)
                .frame(width: 20, height: 30)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Search modes")
    }
}

/// Interactive search (`person`): a movie opens it directly; a series picks a
/// season pack or an episode first (SeasonEpisodePicker).
struct InteractiveSearchButton: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let edition: DetailEdition
    var size: CGFloat = 30
    var glyph: CGFloat = 15

    var body: some View {
        if detail.isSeries {
            Menu {
                Section("Interactive search · \(edition.tier.tierShort) — pick a scope") {
                    ForEach(detail.seasonsNewestFirst) { season in
                        Button {
                            store.interactive = InteractiveTarget(editionIds: [edition.id], seasonNumber: season.seasonNumber,
                                                                  subtitle: "S\(season.seasonNumber) · Season pack")
                        } label: {
                            Label {
                                Text(season.title)
                                Text("\(season.episodes.count) eps · pack")
                            } icon: { Image(systemName: "folder") }
                        }
                    }
                }
                Menu {
                    ForEach(detail.seasonsNewestFirst) { season in
                        Menu(season.title) {
                            ForEach(season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }) { episode in
                                Button {
                                    store.interactive = InteractiveTarget(
                                        editionIds: [edition.id], episodeId: episode.id,
                                        subtitle: "S\(season.seasonNumber)·E\(episode.episodeNumber)")
                                } label: {
                                    Text("S\(season.seasonNumber)·E\(episode.episodeNumber)")
                                    Text(episode.title ?? "TBA")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Pick an episode…", systemImage: "list.bullet")
                }
            } label: {
                glyphView
            }
            .accessibilityLabel("Interactive search")
        } else {
            Button {
                store.interactive = InteractiveTarget(editionIds: [edition.id], subtitle: edition.label)
            } label: {
                glyphView
            }
            .buttonStyle(DetailPressStyle())
            .accessibilityLabel("Interactive search")
        }
    }

    private var glyphView: some View {
        Image(systemName: "person")
            .font(.system(size: glyph))
            .foregroundStyle(Theme.mut)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }
}

// MARK: - Flash strips

/// AutoSearchFlash: "Searching indexers for …" with a sweeping gradient line,
/// then the grabbed / nothing-new outcome; lingers 5s.
struct AutoSearchFlashStrip: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    @State private var sweep: CGFloat = 0

    var body: some View {
        Group {
            if let flash = store.flash {
                HStack(spacing: 13) {
                    switch flash.phase {
                    case .searching:
                        DetailSpinner(size: 17, color: Theme.grab, period: 0.7)
                        (Text("Searching indexers for ") + Text(flash.scope).foregroundColor(Theme.grab).fontWeight(.bold) + Text(" …"))
                    case .done:
                        if flash.grabbed > 0 {
                            Image(systemName: "checkmark.circle").foregroundStyle(Theme.done)
                            (Text("Grabbed \(flash.grabbed) for \(flash.scope)").foregroundColor(Theme.done).fontWeight(.semibold)
                                + Text(flash.score.map { " (+\($0))" } ?? "").foregroundColor(Theme.grab))
                        } else {
                            (Text("Searched \(flash.scope)") + Text(" — no new releases").foregroundColor(Theme.mut))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.panel2)
                .overlay(alignment: .bottomLeading) {
                    GeometryReader { geo in
                        Theme.fusion
                            .frame(width: geo.size.width * sweep, height: 2)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.grab.mix(0.4, Theme.panel2)))
                .padding(.top, 12)
                .transition(.opacity.combined(with: .offset(y: -6)))
                .onChange(of: flash.phase, initial: true) { _, phase in
                    let searching = phase == .searching
                    if reduce { sweep = searching ? 0.9 : 1; return }
                    if searching { sweep = 0 }
                    withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: searching ? 2.2 : 0.3)) {
                        sweep = searching ? 0.9 : 1
                    }
                }
            }
        }
        .detailAnimation(.easeInOut(duration: 0.25), value: store.flash)
    }
}

/// The gradual-search progress strip with a Stop button (SeasonGradualProgress).
struct GradualProgressStrip: View {
    @Environment(DetailStore.self) private var store

    var body: some View {
        if let job = store.gradual {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    DetailSpinner(size: 14, color: Theme.grab)
                    Text("Searching \(job.label) one at a time · \(job.current)/\(job.total)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    Spacer(minLength: 0)
                    Button(job.stopping ? "Stopping…" : "Stop") { Task { await store.stopGradual() } }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Theme.danger)
                        .buttonStyle(.plain)
                        .disabled(job.stopping)
                }
                DetailCoverageBar(total: max(job.total, 1), owned: job.current, color: Theme.grab, height: 4)
            }
            .padding(12)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
            .padding(.top, 12)
        }
    }
}

// MARK: - Attention

/// EditionAttentionBanner, falling back to the unresolved-file count.
struct AttentionBanners: View {
    let editions: [DetailEdition]

    var body: some View {
        ForEach(editions) { edition in
            if let message = edition.attentionMessage, edition.attentionKind != nil {
                banner(message, edition: edition)
            } else if let n = edition.unresolvedFileCount, n > 0 {
                banner("\(n) \(n == 1 ? "file" : "files") couldn't be resolved on the last scan", edition: edition)
            }
        }
    }

    private func banner(_ text: String, edition: DetailEdition) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.stuck)
            (Text(edition.tier.chipLabel + " · ").fontWeight(.bold) + Text(text))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.txt)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.stuck.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.stuck.opacity(0.35)))
        .padding([.horizontal, .top], 12)
    }
}
