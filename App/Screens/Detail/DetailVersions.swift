import SwiftUI
import FusionhaKit

// The Versions panel in its phone layout (components/detail/versions/*):
// a header (summary, disk footprint, the "Tabs show" scope chip, Compare
// seasons / Search all / Add version), the Edition filter, one row per version
// (opening a row focuses the page scope on it), Not tracked rows for the
// missing tier × edition combinations, and Compare seasons.

/// One version's numbers, computed once per load in `DetailStore` so `body`
/// never walks the episodes.
struct VersionSummary {
    let dot: EditionDot
    let status: VersionStatusDisplay
    let movieStatus: MovieVersionStatus?
    let cover: Cover
    /// Per-season coverage, keyed by season number.
    let seasonCovers: [Int: Cover]
    let bytes: Double
    let untrackedNote: String?
    let availability: MovieAvailabilityNote?
    let grabbedLabel: String
    let grabbedValue: String

    init(detail: ItemDetail, edition: DetailEdition, activeQueue: Set<Int>, now: Date) {
        dot = detail.dot(for: edition, activeQueueEditionIds: activeQueue)
        if detail.isSeries {
            var covers: [Int: Cover] = [:]
            var total = Cover()
            for season in detail.seasons ?? [] {
                let c = season.cover(editionId: edition.id, now: now)
                covers[season.seasonNumber] = c
                total = total + c
            }
            seasonCovers = covers
            cover = total
            status = seriesVersionStatus(total)
            movieStatus = nil
            bytes = detail.editionBytes(edition)
            untrackedNote = detail.untrackedNote(total)
            availability = nil
            grabbedLabel = "Files"
            grabbedValue = "\(total.owned)/\(total.total) eps · \(DetailText.bytes(bytes))"
        } else {
            let st = detail.movieVersionStatus(edition, base: dot, now: now)
            movieStatus = st
            status = st.display
            cover = Cover()
            seasonCovers = [:]
            bytes = edition.movieFile?.size ?? 0
            untrackedNote = nil
            availability = edition.movieFile == nil && st != .grab
                ? detail.movieAvailabilityNote(edition, status: st, now: now) : nil
            if edition.movieFile != nil {
                let g = detail.versionGrabbed(edition.id, now: now)
                grabbedLabel = g.label
                grabbedValue = g.value
            } else {
                grabbedLabel = "File"
                grabbedValue = "none yet"
            }
        }
    }
}

extension EditionStatus {
    /// The status glyph a version row shows (colour comes from the status).
    var versionGlyph: String {
        switch self {
        case .downloaded: return "checkmark"
        case .downloading: return "arrow.down.circle"
        case .upgrading: return "arrow.up.circle"
        case .upcoming, .unaired: return "clock"
        case .unmonitored: return "bookmark"
        default: return "circle.dashed"
        }
    }
}

// MARK: - Panel

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
            VStack(spacing: 0) {
                ForEach(visible) { edition in
                    DetailVersionRow(detail: detail, edition: edition, open: focused?.id == edition.id,
                                     readOnly: readOnly, canSearch: canSearch, openWeb: openWeb,
                                     selectedSeason: compareSeason,
                                     onPickSeason: compareAllowed ? { (n: Int) in cmpSeason = n } : nil) {
                        toggle(edition, focused: focused)
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
                ForEach(gaps) { gap in
                    DetailNotTrackedRow(gap: gap, showTag: detail.needsEditionTag, readOnly: readOnly) {
                        store.addPreset = AddEditionPreset(tier: gap.tier, version: gap.edition)
                    }
                }
            }
            if let season = compareSeason {
                DetailCompareSeasons(detail: detail, season: season, versions: visible,
                                     onPick: { cmpSeason = $0 }, onClose: { cmpSeason = nil })
                    .transition(.opacity)
            }
            VStack(spacing: 0) {
                GradualProgressStrip()
                AutoSearchFlashStrip()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, store.gradual != nil || store.flash != nil ? 14 : 0)
        }
        .background(Theme.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line))
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
        VStack(alignment: .leading, spacing: 10) {
            FlowRow(spacing: 10, lineSpacing: 10) {
                HStack(spacing: 10) {
                    Text(summary)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(1)
                    if total > 0 {
                        footprint(onDisk, total: total)
                    }
                }
                scopeChip(focused)
            }
            actions(focused: focused, compareAllowed: compareAllowed, comparing: comparing, visible: visible)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    /// The 96×6 disk-footprint bar; a non-Standard edition's segment is dimmed.
    private func footprint(_ onDisk: [(DetailEdition, Double)], total: Double) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(onDisk.enumerated()), id: \.offset) { _, seg in
                Rectangle()
                    .fill(seg.0.tier.color.opacity(seg.0.versionKey.isEmpty ? 1 : 0.6))
                    .frame(width: 96 * CGFloat(seg.1 / total))
            }
        }
        .frame(width: 96, height: 6, alignment: .leading)
        .background(Theme.txt.opacity(0.07))
        .clipShape(Capsule())
        .accessibilityLabel("Disk footprint · \(DetailText.bytes(total))")
    }

    private func scopeChip(_ focused: DetailEdition?) -> some View {
        HStack(spacing: 6) {
            Text("Tabs show")
                .foregroundStyle(Theme.mut)
            if let focused {
                Text(detail.versionName(focused))
                    .foregroundStyle(focused.tier.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Button {
                    store.scope = .all
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
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
                Text("all versions").foregroundStyle(Theme.txt)
            }
        }
        .font(.system(size: 11.5, weight: .semibold))
        .padding(.leading, 10)
        .padding(.trailing, focused == nil ? 10 : 6)
        .frame(minHeight: 26)
        .background(Theme.txt.opacity(0.03), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line))
        .contentTransition(.opacity)
    }

    @ViewBuilder
    private func actions(focused: DetailEdition?, compareAllowed: Bool, comparing: Bool,
                         visible: [DetailEdition]) -> some View {
        let compare = compareAllowed ? compareButton(comparing: comparing, visible: visible) : nil
        let search = canSearch ? searchAll : nil
        let add = readOnly ? nil : addMenu(focused: focused)
        if let compare, let search, let add {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    compare
                    search
                }
                add
            }
        } else {
            HStack(spacing: 8) {
                if let compare { compare }
                if let search { search }
                if let add { add }
            }
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
            DetailGhostLabel(systemImage: "slider.horizontal.3", text: "Compare seasons", pressed: comparing)
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
            DetailGhostLabel(systemImage: "plus", text: "Add version")
        }
        .accessibilityLabel("Add version")
        .accessibilityHint("Add another version of this title")
    }

    // MARK: Edition filter

    private func filterRow(keys: [String], active: String, focused: DetailEdition?) -> some View {
        HStack(spacing: 8) {
            Text("EDITION")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .tracking(1.05)
                .foregroundStyle(Theme.dim)
            Picker("Edition", selection: Binding(get: { active }, set: { pick($0, focused: focused) })) {
                Text("All").tag("all")
                ForEach(keys, id: \.self) { Text(versionLabel($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func pick(_ next: String, focused: DetailEdition?) {
        filter = next
        if let key = focused?.versionKey, next != "all", next != key { store.scope = .all }
    }
}

/// The panel's dashed ghost button face (`.btn.ghost`), 44pt on the phone.
struct DetailGhostLabel: View {
    let systemImage: String
    let text: String
    var pressed = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
            Text(text).font(.system(size: 13, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(pressed ? Theme.txt : Theme.mut)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(pressed ? Theme.cyan.opacity(0.55) : Theme.line,
                              style: StrokeStyle(lineWidth: 1, dash: pressed ? [] : [4, 3]))
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Identity

/// The tier label with its dot (`.tier`) and, when shown, the edition tag (`.ver`).
struct DetailVersionIdentity: View {
    let tier: QualityTier
    let edition: String
    let showTag: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Circle().fill(tier.color).frame(width: 8, height: 8)
                Text(tier.chipLabel).font(.system(size: 13.5, weight: .bold)).foregroundStyle(tier.color)
            }
            .fixedSize()
            if showTag {
                DetailEditionTag(edition: edition)
            }
        }
    }
}

/// The edition tag: pink (`--variant`), Standard greyed.
struct DetailEditionTag: View {
    let edition: String

    var body: some View {
        let std = edition.isEmpty
        Text(versionLabel(edition))
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(std ? Theme.dim : Theme.anime)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(std ? Theme.line : Theme.anime.opacity(0.35)))
    }
}

// MARK: - Row

struct DetailVersionRow: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail
    let edition: DetailEdition
    let open: Bool
    let readOnly: Bool
    let canSearch: Bool
    let openWeb: () -> Void
    let selectedSeason: Int?
    let onPickSeason: ((Int) -> Void)?
    let onToggle: () -> Void

    var body: some View {
        let summary = store.summary(edition)
        let name = detail.versionName(edition)
        let statusColor = summary?.status.key.color ?? Theme.mut
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Button(action: onToggle) {
                        DetailVersionIdentity(tier: edition.tier, edition: edition.versionKey, showTag: detail.needsEditionTag)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(name)
                    .accessibilityValue(open ? "Expanded" : "Collapsed")
                    sizeText(summary?.bytes ?? 0)
                    if canSearch {
                        SearchActionButton(label: "\(detail.title) — \(name)", editionId: edition.id,
                                           accessibility: "Search \(name)", size: 44, glyph: 15)
                    }
                }
                if let summary {
                    summaryView(summary, statusColor: statusColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            if open {
                DetailVersionDetail(detail: detail, edition: edition, readOnly: readOnly, canSearch: canSearch,
                                    openWeb: openWeb)
                    .transition(reduce ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(open ? Theme.txt.opacity(0.022) : .clear)
        .overlay(alignment: .top) {
            Rectangle().fill(statusColor).frame(height: 2).opacity(open ? 0.9 : 0)
        }
        .clipped()
    }

    private func sizeText(_ bytes: Double) -> some View {
        Text(bytes > 0 ? DetailText.bytes(bytes) : "—")
            .font(.system(size: 12.5, weight: bytes > 0 ? .semibold : .regular, design: .monospaced))
            .foregroundStyle(bytes > 0 ? Theme.txt : Theme.mut)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder
    private func summaryView(_ summary: VersionSummary, statusColor: Color) -> some View {
        let status = HStack(spacing: 6) {
            Image(systemName: summary.status.key.versionGlyph).font(.system(size: 12, weight: .semibold))
            Text(summary.status.text).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(statusColor)
        .fixedSize()
        if detail.isSeries {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    status
                    DetailHealthMarker(edition: edition)
                }
                DetailSeasonBars(detail: detail, edition: edition, covers: summary.seasonCovers,
                                 selected: selectedSeason, onPick: onPickSeason)
                (Text("\(summary.cover.owned)").foregroundColor(Theme.txt)
                    + Text("/\(summary.cover.total)")
                    + Text(summary.untrackedNote.map { " \($0)" } ?? "").foregroundColor(Theme.dim))
                    .font(.system(size: 12, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mut)
                    .accessibilityHint(summary.untrackedNote == nil ? "" : "Kept \(summary.cover.kept) · Not tracked \(summary.cover.untracked)")
            }
        } else {
            FlowRow(spacing: 10, lineSpacing: 8) {
                status
                DetailHealthMarker(edition: edition)
                movieSummary(summary)
            }
        }
    }

    @ViewBuilder
    private func movieSummary(_ summary: VersionSummary) -> some View {
        if let file = edition.movieFile {
            Text(DetailText.quality(file.quality))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.txt.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(edition.tier.color.opacity(0.3)))
            ForEach(Array(DetailVersionRow.mediaChips(file).enumerated()), id: \.offset) { _, chip in
                chipView(chip, color: Theme.mut, border: Theme.line)
            }
            ForEach(file.customFormats ?? [], id: \.self) { cf in
                chipView(cf, color: Theme.edition, border: Theme.edition.opacity(0.3))
            }
        } else if summary.movieStatus == .grab {
            if let release = edition.releaseTitle {
                Text(release).font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(1)
            }
        } else if let avail = summary.availability {
            let color = availColor(avail.kind)
            let cutoff = store.cutoff(edition.qualityProfileId).map { DetailText.quality($0) }
            let tail = summary.movieStatus == .soon ? " · auto-grabs on release" : cutoff.map { " · looking for \($0)" } ?? ""
            (Text(avail.text).fontWeight(.semibold).foregroundColor(color) + Text(tail).foregroundColor(Theme.mut))
                .font(.system(size: 12.5))
        }
    }

    private func availColor(_ kind: MovieAvailabilityNote.Kind) -> Color {
        switch kind {
        case .released: return Theme.miss
        case .upcoming: return Theme.unaired
        case .none: return Theme.txt
        }
    }

    private func chipView(_ text: String, color: Color, border: Color) -> some View {
        Text(text)
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(border))
    }

    /// `movieMediaChips`: release group, codec, audio, HDR (SDR dropped).
    static func mediaChips(_ file: MovieFile) -> [String] {
        var chips: [String] = []
        if let group = file.releaseGroup, !group.isEmpty { chips.append(group) }
        let probe = file.mediaInfo?.probe
        if let v = DetailMediaFacts.codec(probe) { chips.append(v) }
        if let v = DetailMediaFacts.audio(probe) { chips.append(v) }
        if let v = DetailMediaFacts.range(probe), v != "SDR" { chips.append(v) }
        return chips
    }
}

/// The compact FileHealthBadge on a row (attention or unresolved files).
struct DetailHealthMarker: View {
    let edition: DetailEdition

    var body: some View {
        let unresolved = edition.unresolvedCount
        if edition.attentionKind != nil || unresolved > 0 {
            let dead = edition.attentionKind == "dead_content"
            DetailFileHealthBadge(count: unresolved, dead: dead, compact: true)
        }
    }
}

/// FileHealthBadge: the miss-tinted "unresolved" pill (compact = glyph only).
struct DetailFileHealthBadge: View {
    let count: Int
    var dead = false
    var compact = false

    private var label: String {
        if dead { return count > 0 ? "\(count) unreadable · the source is gone" : "Unreadable · the source is gone" }
        return count > 0 ? "\(count) unresolved · not found on last scan" : "Unresolved · not found on last scan"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.dashed").font(.system(size: 10, weight: .bold))
            if !compact { Text(label).font(.system(size: 10.5, weight: .semibold)).lineLimit(1) }
        }
        .foregroundStyle(Theme.miss)
        .padding(.horizontal, compact ? 4 : 7)
        .padding(.vertical, compact ? 2 : 1)
        .background(Theme.miss.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.miss.opacity(0.32)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

// MARK: - Season bars

/// One bar per season, flexed by episode count; filled in the tier colour.
/// A gap season is miss-tinted, an untracked one hatched. Tapping a bar opens
/// Compare seasons at that season (when allowed); it never toggles the row.
struct DetailSeasonBars: View {
    let detail: ItemDetail
    let edition: DetailEdition
    let covers: [Int: Cover]
    let selected: Int?
    let onPick: ((Int) -> Void)?

    var body: some View {
        let seasons = detail.seasonsAscending
        GeometryReader { geo in
            let gap: CGFloat = 3
            let n = CGFloat(max(seasons.count, 1))
            let minW = min(20, (geo.size.width - (n - 1) * gap) / n)
            let weights = seasons.map { CGFloat(max($0.episodes.count, 1)) }
            let widths = Self.widths(weights, total: geo.size.width - (n - 1) * gap, min: minW)
            HStack(spacing: gap) {
                ForEach(Array(seasons.enumerated()), id: \.element.id) { i, season in
                    bar(season, width: widths[i])
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 44)
        // Interactive bars open Compare seasons and never toggle the row;
        // otherwise a tap falls through to the row.
        .contentShape(Rectangle())
        .onTapGesture {}
        .allowsHitTesting(onPick != nil)
    }

    /// Flex widths with a per-bar floor (the CSS `min-width` on touch).
    static func widths(_ weights: [CGFloat], total: CGFloat, min floor: CGFloat) -> [CGFloat] {
        guard !weights.isEmpty, total > 0 else { return weights.map { _ in 0 } }
        var fixed = Set<Int>()
        var out = weights.map { _ in CGFloat(0) }
        for _ in 0..<weights.count {
            let free = total - CGFloat(fixed.count) * floor
            let sum = weights.indices.filter { !fixed.contains($0) }.reduce(CGFloat(0)) { $0 + weights[$1] }
            var changed = false
            for i in weights.indices where !fixed.contains(i) {
                out[i] = sum > 0 ? free * weights[i] / sum : 0
                if out[i] < floor { fixed.insert(i); changed = true }
            }
            for i in fixed { out[i] = floor }
            if !changed { break }
        }
        return out
    }

    @ViewBuilder
    private func bar(_ season: Season, width: CGFloat) -> some View {
        let c = covers[season.seasonNumber] ?? Cover()
        let off = season.isOff(c)
        let fraction = off || c.total == 0 ? 0 : Double(c.owned) / Double(c.total)
        let gapSeason = !off && c.wanted > 0
        let isSelected = selected == season.seasonNumber
        let label = off
            ? "Season \(season.seasonNumber) · \(c.kept + c.untracked) · not tracked"
            : "Season \(season.seasonNumber) · \(c.owned)/\(c.total)\(c.unaired > 0 ? " · \(c.unaired) unaired" : "")\(onPick != nil ? " · compare this season across versions" : "")"
        let shape = RoundedRectangle(cornerRadius: 3)
        let face = ZStack(alignment: .leading) {
            if off {
                DetailHatch().clipShape(shape)
            } else {
                shape.fill(gapSeason ? Theme.miss.opacity(0.16) : Theme.txt.opacity(0.07))
                if gapSeason { shape.strokeBorder(Theme.miss.opacity(0.4), lineWidth: 1) }
            }
            shape.fill(edition.tier.color).frame(width: width * fraction)
        }
        .frame(width: width, height: 8)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.txt, lineWidth: 1.5).padding(-2.5)
            }
        }
        if let onPick {
            Button { onPick(season.seasonNumber) } label: {
                face.frame(maxHeight: .infinity).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        } else {
            face.accessibilityLabel(label)
        }
    }
}

/// The 135° hatch of an untracked season (`repeating-linear-gradient`).
struct DetailHatch: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 6
            }
            ctx.stroke(path, with: .color(Theme.txt.opacity(0.08)), lineWidth: 3)
        }
    }
}

// MARK: - Episode ticks

/// One tick per episode of a season for one version; tap shows its tooltip.
struct DetailEpisodeTicks: View {
    @Environment(\.detailReduceMotion) private var reduce
    let season: Season
    let edition: DetailEdition
    /// The version named in the tooltip (Compare seasons), or nil.
    var versionLabel: String?
    @State private var tip: Int?

    var body: some View {
        let now = Date()
        FlowRow(spacing: 3, lineSpacing: 3) {
            ForEach(season.episodes) { episode in
                let kind = season.tick(episode, editionId: edition.id, now: now)
                tick(kind)
                    .frame(width: 15, height: 9)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { tip = tip == episode.id ? nil : episode.id }
                    .popover(isPresented: Binding(get: { tip == episode.id }, set: { if !$0 { tip = nil } })) {
                        tooltip(episode, kind: kind, now: now)
                            .presentationCompactAdaptation(.popover)
                    }
                    .accessibilityElement()
                    .accessibilityLabel(accessibility(episode, kind: kind, now: now))
            }
        }
    }

    @ViewBuilder
    private func tick(_ kind: TickKind) -> some View {
        let shape = RoundedRectangle(cornerRadius: 2)
        switch kind {
        case .owned:
            shape.fill(edition.tier.color)
        case .grab:
            shape.fill(Theme.grab).detailPulse(low: 0.55, high: 1, period: 1.5)
        case .want:
            shape.strokeBorder(Theme.miss.mix(0.45, Theme.line), lineWidth: 1)
        case .soon:
            shape.strokeBorder(Theme.line, lineWidth: 1).opacity(0.7)
        case .untracked:
            shape.strokeBorder(Theme.txt.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [1, 1.5])).opacity(0.6)
        }
    }

    private func code(_ episode: Episode) -> String {
        "S\(season.seasonNumber)·E\(String(format: "%02d", episode.episodeNumber))"
    }

    private func statusText(_ episode: Episode, kind: TickKind, now: Date) -> String {
        kind == .untracked ? "Not tracked" : episode.status(editionId: edition.id, now: now).statusText
    }

    private func accessibility(_ episode: Episode, kind: TickKind, now: Date) -> String {
        let st = statusText(episode, kind: kind, now: now)
        if let versionLabel { return "\(code(episode)) · \(versionLabel) — \(st)" }
        return "\(code(episode)) \(episode.title ?? "Episode \(episode.episodeNumber)") — \(st)"
    }

    private func tooltip(_ episode: Episode, kind: TickKind, now: Date) -> some View {
        let quality = episode.file(for: edition.id).map { DetailText.quality($0.quality) }
        let dot: Color = switch kind {
        case .owned: Theme.done
        case .grab: Theme.grab
        case .want: Theme.miss
        case .soon: Theme.unaired
        case .untracked: Theme.dim
        }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(code(episode)).font(.system(size: 12, weight: .bold, design: .monospaced))
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(dot).frame(width: 8, height: 8)
                    Text(statusText(episode, kind: kind, now: now) + (quality.map { " · \($0)" } ?? ""))
                }
                .font(.system(size: 11))
            }
            Text((versionLabel.map { "\($0) · " } ?? "") + (episode.title ?? "Episode \(episode.episodeNumber)"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.mut)
        }
        .foregroundStyle(Theme.txt)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: 280, alignment: .leading)
    }
}

// MARK: - Opened row

struct DetailVersionDetail: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let edition: DetailEdition
    let readOnly: Bool
    let canSearch: Bool
    let openWeb: () -> Void

    @State private var pickedSeason: Int?

    var body: some View {
        let name = detail.versionName(edition)
        let summary = store.summary(edition)
        VStack(alignment: .leading, spacing: 14) {
            if !readOnly {
                actionBar(name)
            }
            specGrid(summary)
            if let kind = edition.attentionKind {
                DetailAttentionBanner(kind: kind, message: edition.attentionMessage ?? "", readOnly: readOnly,
                                      onRescan: { Task { await store.refresh(metadataOnly: false) } },
                                      onSearch: { Task { await store.search(label: "\(detail.title) — \(name)", editionId: edition.id) } },
                                      onReplace: { Task { await store.replaceDead(edition) } },
                                      onManage: openWeb)
            }
            if detail.isSeries, let summary {
                seasons(summary, name: name)
            } else if let path = edition.movieFile?.relativePath {
                Text(path)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .padding(.top, 2)
    }

    // MARK: Action bar

    private func actionBar(_ name: String) -> some View {
        HStack(spacing: 8) {
            if canSearch {
                HStack(spacing: 0) {
                    SearchActionButton(label: "\(detail.title) — \(name)", editionId: edition.id,
                                       accessibility: "Search \(name)", glyph: 15, title: "Search", framed: false)
                    Rectangle().fill(Theme.line).frame(width: 1, height: 44)
                    SearchModeMenu(detail: detail, edition: edition, width: 44, height: 44)
                }
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
                .layoutPriority(1.5)
                InteractiveSearchButton(detail: detail, edition: edition) {
                    barLabel("person", "Choose")
                }
            }
            Button { store.showingEdit = true } label: { barLabel("pencil", "Edit") }
                .buttonStyle(DetailPressStyle())
                .accessibilityLabel("Edit \(name)")
        }
    }

    private func barLabel(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage).font(.system(size: 15))
            Text(text).font(.system(size: 13, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(Theme.txt)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
        .contentShape(Rectangle())
    }

    // MARK: Spec grid

    private func specGrid(_ summary: VersionSummary?) -> some View {
        let cutoffCode = store.cutoff(edition.qualityProfileId)
        let met = !detail.isSeries && edition.movieFile != nil
            && DetailText.meetsCutoff(edition.movieFile?.quality, cutoff: cutoffCode)
        let monitored = store.editionMonitored(edition)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                specCell("Root folder") { specValue(store.rootPath(edition)) }
                Rectangle().fill(Theme.line).frame(width: 1)
                specCell("Profile") { specValue(store.profileName(edition.qualityProfileId)) }
            }
            .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 0) {
                specCell("Cutoff") {
                    HStack(spacing: 4) {
                        specValue(cutoffCode.map { DetailText.quality($0) } ?? "—", color: met ? Theme.done : Theme.txt)
                        if met { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.done) }
                    }
                    .accessibilityHint(met ? "Cutoff met" : "")
                }
                Rectangle().fill(Theme.line).frame(width: 1)
                specCell("Monitoring") {
                    Label(monitored ? "Monitored" : "Not monitored", systemImage: monitored ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12.5, weight: .semibold))
                        .labelStyle(DetailTightLabel())
                        .foregroundStyle(monitored ? Theme.cyan : Theme.mut)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Theme.line).frame(height: 1)
            specCell(summary?.grabbedLabel ?? "File") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        specValue(summary?.grabbedValue ?? "—")
                        if edition.attentionKind == nil, edition.unresolvedCount > 0 {
                            DetailFileHealthBadge(count: edition.unresolvedCount)
                        }
                    }
                    if let c = summary?.cover, c.kept > 0 || c.untracked > 0 {
                        HStack(spacing: 10) {
                            if c.kept > 0 { legend("Kept", c.kept) }
                            if c.untracked > 0 { legend("Not tracked", c.untracked) }
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    private func specCell<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Theme.dim)
            value()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func specValue(_ text: String, color: Color = Theme.txt) -> some View {
        Text(text)
            .font(.system(size: 12.5, design: .monospaced))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func legend(_ label: String, _ n: Int) -> some View {
        (Text("\(label) ") + Text("\(n)").fontWeight(.semibold).foregroundColor(Theme.txt))
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.mut)
    }

    // MARK: Seasons

    @ViewBuilder
    private func seasons(_ summary: VersionSummary, name: String) -> some View {
        let seasons = detail.seasonsAscending
        let selectedNumber = pickedSeason ?? detail.defaultSeason(editionIds: [edition.id])
        let selected = seasons.first { $0.seasonNumber == selectedNumber }
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(seasons) { season in
                    seasonChip(season, cover: summary.seasonCovers[season.seasonNumber] ?? Cover(),
                               pressed: season.seasonNumber == selected?.seasonNumber)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        if let selected {
            let c = summary.seasonCovers[selected.seasonNumber] ?? Cover()
            let off = selected.isOff(c)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Season \(selected.seasonNumber)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                    Text(off ? "\(c.kept + c.untracked) · not tracked"
                         : "\(c.owned)/\(c.total)\(c.grabbing > 0 ? " · grabbing \(c.grabbing)" : "")\(c.unaired > 0 ? " · \(c.unaired) unaired" : "")")
                        .font(.system(size: 12, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(Theme.mut)
                    Spacer(minLength: 0)
                    if canSearch && !off {
                        SearchActionButton(label: "\(detail.title) — \(name) · S\(selected.seasonNumber)",
                                           editionId: edition.id, season: selected.seasonNumber,
                                           accessibility: "Search \(name) — S\(selected.seasonNumber)",
                                           size: 44, glyph: 14)
                    }
                }
                .frame(minHeight: 44)
                DetailEpisodeTicks(season: selected, edition: edition)
            }
        }
    }

    private func seasonChip(_ season: Season, cover c: Cover, pressed: Bool) -> some View {
        let off = season.isOff(c)
        let state = c.chipState
        let fraction = off || c.total == 0 ? 0 : Double(c.owned) / Double(c.total)
        let frac = off ? "\(c.kept)/\(c.kept + c.untracked)" : "\(c.owned)/\(c.total)"
        return Button {
            pickedSeason = season.seasonNumber
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("S\(season.seasonNumber)").font(.system(size: 12.5, weight: .bold))
                    Spacer(minLength: 0)
                    mark(off: off, state: state, owned: c.owned)
                }
                Capsule().fill(Theme.txt.opacity(0.07))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule().fill(edition.tier.color).frame(width: geo.size.width * fraction)
                        }
                    }
                    .clipShape(Capsule())
                Text(frac).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
            }
            .foregroundStyle(off ? Theme.dim : Theme.txt)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 86, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(pressed ? Theme.cyan.opacity(0.55) : Theme.line,
                                  style: StrokeStyle(lineWidth: 1, dash: off && !pressed ? [4, 3] : []))
            }
            .background {
                if pressed { RoundedRectangle(cornerRadius: 10).stroke(Theme.cyan.opacity(0.1), lineWidth: 6) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(off ? "Season \(season.seasonNumber) — not monitored, \(frac) held"
                            : "Season \(season.seasonNumber) — \(frac)")
        .accessibilityAddTraits(pressed ? .isSelected : [])
    }

    @ViewBuilder
    private func mark(off: Bool, state: Cover.ChipState, owned: Int) -> some View {
        if off {
            Text("⊘").font(.system(size: 12)).foregroundStyle(Theme.dim)
        } else {
            switch state {
            case .done:
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.done)
            case .soon:
                Text(owned > 0 ? "◐" : "○").font(.system(size: 12)).foregroundStyle(Theme.unaired)
            case .part:
                Text("◐").font(.system(size: 12)).foregroundStyle(Theme.miss)
            case .empty:
                Text("○").font(.system(size: 12)).foregroundStyle(Theme.miss)
            }
        }
    }
}

/// Icon + title with the tighter 6pt gap the spec grid uses.
struct DetailTightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 12))
            configuration.title
        }
    }
}

// MARK: - Attention banner

/// VersionAttentionBanner: why a version needs attention, plus its fixes.
/// Not-found's primary fix is a rescan; a dead link's is a re-grab.
struct DetailAttentionBanner: View {
    let kind: String
    let message: String
    let readOnly: Bool
    let onRescan: () -> Void
    let onSearch: () -> Void
    let onReplace: () -> Void
    let onManage: () -> Void

    var body: some View {
        let regrab = kind == "dead_link" || kind == "dead_content"
        let color = regrab ? Theme.stuck : Theme.miss
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: regrab ? "link" : "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundStyle(color)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(message).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                if !regrab {
                    Text("Nothing has been deleted.").font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
                if !readOnly {
                    FlowRow(spacing: 8, lineSpacing: 8) {
                        if !regrab {
                            action("arrow.clockwise", "Rescan this root", color: color, onRescan)
                        }
                        action("magnifyingglass",
                               regrab ? "Search replacement" : kind == "partial" ? "Search the missing" : "Search",
                               color: color, regrab ? onReplace : onSearch)
                        action("folder", "Manage files", color: color, onManage)
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.mix(0.08, Theme.panel), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.mix(0.45, Theme.line)))
        .accessibilityElement(children: .contain)
    }

    private func action(_ icon: String, _ text: String, color: Color, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
                Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.mix(0.4, Theme.line)))
        }
        .buttonStyle(DetailPressStyle())
    }
}

// MARK: - Not tracked

/// A missing tier × edition combination: dimmed identity, "Not tracked", + Add.
struct DetailNotTrackedRow: View {
    let gap: MissingVersion
    let showTag: Bool
    let readOnly: Bool
    let onAdd: () -> Void

    var body: some View {
        let addLabel = "Add \(versionLabel(gap.edition)) · \(gap.tier.chipLabel)"
        HStack(spacing: 14) {
            DetailVersionIdentity(tier: gap.tier, edition: gap.edition, showTag: !gap.edition.isEmpty || showTag)
                .opacity(0.7)
            Text("Not tracked")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.dim)
            Spacer(minLength: 0)
            if !readOnly {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                        Text("Add").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.mut)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 44, minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .contentShape(Rectangle())
                }
                .buttonStyle(DetailPressStyle())
                .accessibilityLabel(addLabel)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Line().stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])).frame(height: 1)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

// MARK: - Compare seasons

/// One season across every visible version, episode by episode.
struct DetailCompareSeasons: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let season: Int
    let versions: [DetailEdition]
    let onPick: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        let selected = detail.seasonsAscending.first { $0.seasonNumber == season }
        let tracked = detail.trackedSeasons(editionIds: versions.map(\.id))
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                (Text(selected.map { "Season \($0.seasonNumber)" } ?? "Season").fontWeight(.bold).foregroundColor(Theme.txt)
                    + Text("  every version, episode by episode").foregroundColor(Theme.mut))
                    .font(.system(size: 13))
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(DetailPressStyle())
                .padding(.vertical, -12)
                .accessibilityLabel("Close comparison")
            }
            FlowRow(spacing: 4, lineSpacing: 4) {
                ForEach(tracked) { s in
                    let on = s.seasonNumber == season
                    Button { onPick(s.seasonNumber) } label: {
                        Text("S\(s.seasonNumber)")
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(on ? Theme.txt : Theme.mut)
                            .frame(minWidth: 44, minHeight: 44)
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(on ? Theme.cyan.opacity(0.55) : Theme.line))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            if let selected {
                ForEach(versions) { edition in
                    line(selected, edition)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Theme.txt.opacity(0.015))
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func line(_ season: Season, _ edition: DetailEdition) -> some View {
        let key = edition.versionKey
        let tagged = !key.isEmpty || detail.needsEditionTag
        let label = tagged ? "\(versionLabel(key)) · \(edition.tier.chipLabel)" : edition.tier.chipLabel
        let c = store.summary(edition)?.seasonCovers[season.seasonNumber] ?? Cover()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                DetailVersionIdentity(tier: edition.tier, edition: key, showTag: tagged)
                Spacer(minLength: 0)
                DetailEpisodeTicks(season: season, edition: edition, versionLabel: label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            (Text("\(c.owned)").foregroundColor(Theme.txt) + Text("/\(c.total)"))
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Theme.mut)
        }
    }
}
