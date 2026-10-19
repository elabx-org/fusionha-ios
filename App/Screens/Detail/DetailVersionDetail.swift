import SwiftUI
import FusionhaKit

// MARK: - Opened card

/// The opened version, inside its card: glass Search ▾ / Choose / Edit, the
/// spec grid, the attention banner, and the season chips with episode ticks.
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
                                      onSearch: { Task { await store.search(label: "\(detail.title) · \(name)", editionId: edition.id) } },
                                      onReplace: { Task { await store.replaceDead(edition) } },
                                      onManage: { store.manageFiles = ManageFilesTarget(versionIds: [edition.id]) })
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
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .padding(.top, 4)
    }

    // MARK: Action bar

    private func actionBar(_ name: String) -> some View {
        HStack(spacing: 8) {
            if canSearch {
                HStack(spacing: 0) {
                    SearchActionButton(label: "\(detail.title) · \(name)", editionId: edition.id,
                                       accessibility: "Search \(name)", glyph: 15, title: "Search", framed: false)
                    Rectangle().fill(Theme.line).frame(width: 1, height: 22)
                    SearchModeMenu(detail: detail, edition: edition, width: 40, height: 44)
                }
                .padding(.leading, 6)
                // One glass capsule for the split: Search | ▾.
                .glassControl()
                // Room for "Search" + the mode chevron; Choose and Edit share the rest.
                .frame(minWidth: 132, maxWidth: .infinity)
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
        DetailGlassLabel(systemImage: systemImage, text: text, height: 44, fill: true)
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
                        .foregroundStyle(monitored ? Theme.txt : Theme.mut)
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
        .background(Theme.bg.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func specCell<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
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
                        SearchActionButton(label: "\(detail.title) · \(name) · S\(selected.seasonNumber)",
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
                            Capsule().fill(DetailTokens.tier(edition.tier)).frame(width: geo.size.width * fraction)
                        }
                    }
                    .clipShape(Capsule())
                Text(frac).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
            }
            .foregroundStyle(off ? Theme.dim : Theme.txt)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 86, alignment: .leading)
            .background(pressed ? Theme.panel2 : Theme.bg.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(pressed ? Theme.txt.opacity(0.55) : Theme.line,
                                  style: StrokeStyle(lineWidth: 1, dash: off && !pressed ? [4, 3] : []))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(off ? "Season \(season.seasonNumber) — not monitored, \(frac) held"
                            : "Season \(season.seasonNumber) · \(frac)")
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
