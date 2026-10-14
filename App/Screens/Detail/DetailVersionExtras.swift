import SwiftUI
import FusionhaKit

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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(color.mix(0.08, Theme.panel), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(color.mix(0.45, Theme.line)))
        .accessibilityElement(children: .contain)
    }

    private func action(_ icon: String, _ text: String, color: Color, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
                Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .contentShape(Capsule())
        }
        .buttonStyle(DetailPressStyle())
        .glassControl()
    }
}

// MARK: - Not tracked

/// A missing tier × edition combination as an empty shelf slot (a dashed
/// outline, no fill): dimmed identity, "Not tracked", and a glass + Add.
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
                .font(.system(size: 13))
                .foregroundStyle(Theme.dim)
            Spacer(minLength: 0)
            if !readOnly {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                        Text("Add").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.txt)
                    .padding(.horizontal, 14)
                    .frame(minWidth: 44, minHeight: 36)
                    .contentShape(Capsule())
                }
                .buttonStyle(DetailPressStyle())
                .glassControl()
                .accessibilityLabel(addLabel)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.txt.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }
}

// MARK: - Compare seasons

/// One season across every visible version, episode by episode: a card of
/// its own under the version cards.
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
                            .background(on ? Theme.panel2 : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(on ? Theme.txt.opacity(0.55) : Theme.line))
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
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .detailCard()
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
