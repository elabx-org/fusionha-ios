import SwiftUI
import FusionhaKit

// MARK: - Identity

/// The lit tier chip (`.ed.lg`: `HD·1080p` purple, `UHD·4K` cyan) and, when
/// shown, the edition tag (`.ver`).
struct DetailVersionIdentity: View {
    let tier: QualityTier
    let edition: String
    let showTag: Bool

    var body: some View {
        HStack(spacing: 8) {
            TierPill(tier: tier, large: true)
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

// MARK: - Card

/// One version as a shelf object (`.obj.ver`): the lit tier chip and its size,
/// the status line, the quality / media chips with a round glass search, the
/// season bars; tapping it opens the version (and scopes the page to it).
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
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button(action: onToggle) {
                        DetailVersionIdentity(tier: edition.tier, edition: edition.versionKey, showTag: detail.needsEditionTag)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(name)
                    .accessibilityValue(open ? "Expanded" : "Collapsed")
                    sizeText(summary?.bytes ?? 0)
                    if canSearch {
                        SearchActionButton(label: "\(detail.title) — \(name)", editionId: edition.id,
                                           accessibility: "Search \(name)", size: 36, glyph: 15, bordered: true)
                    }
                }
                if let summary {
                    summaryView(summary, statusColor: statusColor)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, open ? 8 : 16)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            if open {
                DetailVersionDetail(detail: detail, edition: edition, readOnly: readOnly, canSearch: canSearch,
                                    openWeb: openWeb)
                    .transition(reduce ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(shape)
        .detailCard()
        // The opened card is ringed in its status colour, never filled.
        .overlay(shape.strokeBorder(statusColor.opacity(open ? 0.45 : 0), lineWidth: 1))
    }

    /// `61.2 GB` (`.vsize`).
    private func sizeText(_ bytes: Double) -> some View {
        Text(bytes > 0 ? DetailText.bytes(bytes) : "—")
            .font(.system(size: 15, weight: bytes > 0 ? .semibold : .regular))
            .foregroundStyle(bytes > 0 ? Theme.txt : Theme.mut)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder
    private func summaryView(_ summary: VersionSummary, statusColor: Color) -> some View {
        let status = HStack(spacing: 6) {
            Image(systemName: summary.status.key.versionGlyph).font(.system(size: 13, weight: .semibold))
            Text(summary.status.text).font(.system(size: 15, weight: .semibold))
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
                    .font(.system(size: 13, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mut)
                    .accessibilityHint(summary.untrackedNote == nil ? "" : "Kept \(summary.cover.kept) · Not tracked \(summary.cover.untracked)")
            }
        } else {
            FlowRow(spacing: 6, lineSpacing: 6) {
                status
                DetailHealthMarker(edition: edition)
                movieSummary(summary)
            }
        }
    }

    @ViewBuilder
    private func movieSummary(_ summary: VersionSummary) -> some View {
        if let file = edition.movieFile {
            chipView(DetailText.quality(file.quality), color: Theme.txt)
            ForEach(Array(DetailVersionRow.mediaChips(file).enumerated()), id: \.offset) { _, chip in
                chipView(chip, color: Theme.mut)
            }
            ForEach(file.customFormats ?? [], id: \.self) { cf in
                chipView(cf, color: Theme.mut)
            }
        } else if summary.movieStatus == .grab {
            if let release = edition.releaseTitle {
                Text(release).font(.system(size: 13)).foregroundStyle(Theme.mut).lineLimit(1)
            }
        } else if let avail = summary.availability {
            let color = availColor(avail.kind)
            let cutoff = store.cutoff(edition.qualityProfileId).map { DetailText.quality($0) }
            let tail = summary.movieStatus == .soon ? " · auto-grabs on release" : cutoff.map { " · looking for \($0)" } ?? ""
            (Text(avail.text).fontWeight(.semibold).foregroundColor(color) + Text(tail).foregroundColor(Theme.mut))
                .font(.system(size: 15))
        }
    }

    private func availColor(_ kind: MovieAvailabilityNote.Kind) -> Color {
        switch kind {
        case .released: return Theme.miss
        case .upcoming: return Theme.unaired
        case .none: return Theme.txt
        }
    }

    /// A quality / media / CF chip (`.qchips span`): mono 11 on a faint fill.
    private func chipView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.txt.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
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
