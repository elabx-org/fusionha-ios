import SwiftUI
import FusionhaKit

/// The Versions section (redesign `.section-h` + `.vhead` + `.vacts` +
/// `.versions`): the "Versions" header with the summary, the disk footprint
/// and the "Tabs show" scope chip, Compare seasons / Search all / Add version,
/// the Edition filter, one card per version (opening a card focuses the page
/// scope on it), Not tracked cards for the missing tier × edition
/// combinations, and Compare seasons.
struct DetailVersionsPanel: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail
    let openWeb: () -> Void

    @State private var filter = "all"
    @State private var cmpSeason: Int?

    private var readOnly: Bool { !(model.me?.can("edit") ?? true) }
    private var canSearch: Bool { !readOnly && (model.me?.can("search") ?? true) }

    var body: some View {
        let versions = detail.versionsSorted
        let keys = detail.editionKeysSorted
        let focused = store.focusedVersion
        let activeFilter = filter != "all" && keys.contains(filter) ? filter : "all"
        let visible = versions.filter { activeFilter == "all" || $0.versionKey == activeFilter }
        let gaps = detail.missingVersions.filter { activeFilter == "all" || $0.edition == activeFilter }
        let compareAllowed = detail.isSeries && visible.count > 1 && focused == nil
        let compareSeason = compareAllowed ? cmpSeason : nil

        VStack(alignment: .leading, spacing: 0) {
            header(versions: versions, focused: focused, compareAllowed: compareAllowed,
                   comparing: compareSeason != nil, visible: visible)
            if keys.count > 1 {
                filterRow(keys: keys, active: activeFilter, focused: focused)
            }
            // Each version is its own shelf object (`.obj.ver`), not a row in a panel.
            VStack(spacing: 10) {
                ForEach(visible) { edition in
                    DetailVersionRow(detail: detail, edition: edition, open: focused?.id == edition.id,
                                     readOnly: readOnly, canSearch: canSearch, openWeb: openWeb,
                                     selectedSeason: compareSeason,
                                     onPickSeason: compareAllowed ? { (n: Int) in cmpSeason = n } : nil) {
                        toggle(edition, focused: focused)
                    }
                }
                ForEach(gaps) { gap in
                    DetailNotTrackedRow(gap: gap, showTag: detail.needsEditionTag, readOnly: readOnly) {
                        store.addPreset = AddEditionPreset(tier: gap.tier, version: gap.edition)
                    }
                }
                if let season = compareSeason {
                    DetailCompareSeasons(detail: detail, season: season, versions: visible,
                                         onPick: { cmpSeason = $0 }, onClose: { cmpSeason = nil })
                        .transition(.opacity)
                }
            }
            GradualProgressStrip()
            AutoSearchFlashStrip()
        }
        .detailAnimation(.snappy(duration: 0.3), value: store.scope)
        .detailAnimation(.easeOut(duration: 0.2), value: compareSeason)
        .task {
            #if DEBUG
            // CI screenshots: open Compare seasons on its default season.
            if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_DETAIL_COMPARE"] != nil, compareAllowed {
                cmpSeason = detail.defaultSeason(editionIds: visible.map(\.id))
            }
            #endif
        }
        .onChange(of: focused?.versionKey) { _, key in
            // An externally focused version hidden by the filter drops the filter.
            if let key, filter != "all", filter != key { filter = "all" }
        }
    }

    private func toggle(_ edition: DetailEdition, focused: DetailEdition?) {
        if focused?.id == edition.id {
            store.scope = .all
        } else {
            store.scope = DetailScope(tier: edition.tier.rawValue, version: edition.versionKey)
        }
    }

    // MARK: Header

    @ViewBuilder
    private func header(versions: [DetailEdition], focused: DetailEdition?, compareAllowed: Bool,
                        comparing: Bool, visible: [DetailEdition]) -> some View {
        let sized = versions.map { ($0, store.summary($0)?.bytes ?? 0) }
        let onDisk = sized.filter { $0.1 > 0 }
        let total = onDisk.reduce(0.0) { $0 + $1.1 }
        let summary = (["\(versions.count) \(versions.count == 1 ? "version" : "versions")", "\(onDisk.count) on disk"]
                       + (total > 0 ? [DetailText.bytes(total)] : [])).joined(separator: " · ")
        VStack(alignment: .leading, spacing: 0) {
            DetailSection(title: "Versions", see: summary)
            HStack(spacing: 12) {
                if total > 0 {
                    footprint(onDisk, total: total)
                } else {
                    Spacer(minLength: 0)
                }
                scopeChip(focused)
                    .layoutPriority(1)
            }
            .padding(.bottom, 12)
            actions(focused: focused, compareAllowed: compareAllowed, comparing: comparing, visible: visible)
                .padding(.bottom, 12)
        }
    }

    /// The disk-footprint bar (`.foot-bar`): one segment per version on disk,
    /// sized by its bytes, in the tier colour; a non-Standard edition's is dimmed.
    private func footprint(_ onDisk: [(DetailEdition, Double)], total: Double) -> some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - CGFloat(max(onDisk.count - 1, 0)) * 2, 0)
            HStack(spacing: 2) {
                ForEach(Array(onDisk.enumerated()), id: \.offset) { _, seg in
                    StatusSwatch(token: seg.0.tier.monoToken, shape: Rectangle(),
                                 color: DetailTokens.tier(seg.0.tier).opacity(seg.0.versionKey.isEmpty ? 1 : 0.6))
                        .frame(width: usable * CGFloat(seg.1 / total))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 6)
        .background(Theme.txt.opacity(0.07))
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityLabel("Disk footprint · \(DetailText.bytes(total))")
    }

    /// "Tabs show all versions" (`.scope`): what the tabs below are scoped to.
    private func scopeChip(_ focused: DetailEdition?) -> some View {
        HStack(spacing: 5) {
            Text("Tabs show")
                .foregroundStyle(Theme.mut)
            if let focused {
                Text(detail.versionName(focused))
                    .fontWeight(.semibold)
                    .foregroundStyle(DetailTokens.tier(focused.tier))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Button {
                    store.scope = .all
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.mut)
                        .frame(width: 20, height: 20)
                        .background(Theme.txt.opacity(0.08), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(DetailPressStyle())
                .padding(.vertical, -12)
                .padding(.leading, -8)
                .padding(.trailing, -10)
                .accessibilityLabel("Show all versions")
            } else {
                Text("all versions").fontWeight(.semibold).foregroundStyle(Theme.txt)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .lineLimit(1)
        .padding(.leading, 10)
        .padding(.trailing, focused == nil ? 10 : 6)
        .frame(minHeight: 30)
        .overlay(Capsule().strokeBorder(Theme.line))
        .contentTransition(.opacity)
    }

    /// Compare seasons · Search all · Add version (`.vacts`): glass capsules.
    private func actions(focused: DetailEdition?, compareAllowed: Bool, comparing: Bool,
                         visible: [DetailEdition]) -> some View {
        GlassEffectContainer(spacing: 4) {
            FlowRow(spacing: 8, lineSpacing: 8) {
                if compareAllowed { compareButton(comparing: comparing, visible: visible) }
                if canSearch { searchAll }
                if !readOnly { addMenu(focused: focused) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func compareButton(comparing: Bool, visible: [DetailEdition]) -> some View {
        Button {
            if comparing {
                cmpSeason = nil
            } else {
                cmpSeason = detail.defaultSeason(editionIds: visible.map(\.id))
            }
        } label: {
            DetailGlassLabel(systemImage: "slider.horizontal.3", text: "Compare seasons", on: comparing)
        }
        .buttonStyle(DetailPressStyle())
        .accessibilityAddTraits(comparing ? .isSelected : [])
    }

    private var searchAll: some View {
        SearchActionButton(label: "\(detail.title) — all monitored versions",
                           accessibility: "Search all monitored versions", glyph: 14, title: "Search all")
    }

    private func addMenu(focused: DetailEdition?) -> some View {
        let missing = detail.missingVersions
        let showTag = detail.needsEditionTag
        let firstTier = detail.versionsSorted.first?.tier ?? .hd
        return Menu {
            if !missing.isEmpty {
                Section("Add a version") {
                    ForEach(missing) { gap in
                        Button(gap.edition.isEmpty && !showTag
                               ? gap.tier.chipLabel
                               : "\(gap.tier.chipLabel) · \(versionLabel(gap.edition))") {
                            store.addPreset = AddEditionPreset(tier: gap.tier, version: gap.edition)
                        }
                    }
                }
            }
            Button {
                store.addPreset = AddEditionPreset(tier: focused?.tier ?? firstTier, version: nil)
            } label: {
                Label("New edition (\(detail.isSeries ? "Colour, B&W…" : "Director’s Cut, Extended…"))", systemImage: "plus")
            }
        } label: {
            DetailGlassLabel(systemImage: "plus", text: "Add version")
        }
        .accessibilityLabel("Add version")
        .accessibilityHint("Add another version of this title")
    }

    // MARK: Edition filter

    private func filterRow(keys: [String], active: String, focused: DetailEdition?) -> some View {
        let picker = Picker("Edition", selection: Binding(get: { active }, set: { pick($0, focused: focused) })) {
            Text("All").tag("all")
            ForEach(keys, id: \.self) { Text(versionLabel($0)).tag($0) }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        return HStack(spacing: 10) {
            Text("Edition")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.dim)
                .fixedSize()
            // Like the web's wrapping filter row: the segments keep their
            // natural width and scroll sideways when they outgrow the panel.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    picker
                    Spacer(minLength: 0)
                }
                ScrollView(.horizontal, showsIndicators: false) { picker }
            }
        }
        .padding(.bottom, 12)
    }

    private func pick(_ next: String, focused: DetailEdition?) {
        filter = next
        if let key = focused?.versionKey, next != "all", next != key { store.scope = .all }
    }
}
