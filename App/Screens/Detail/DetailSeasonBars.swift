import SwiftUI
import FusionhaKit

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
            shape.fill(DetailTokens.tier(edition.tier)).frame(width: width * fraction)
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
            shape.fill(DetailTokens.tier(edition.tier))
        case .grab:
            StatusSwatch(token: .grab, shape: shape).detailPulse(low: 0.55, high: 1, period: 1.5)
        case .want:
            shape.strokeBorder(Theme.miss.mix(0.45, Theme.line), lineWidth: 1)
        case .soon:
            shape.strokeBorder(Theme.line, lineWidth: 1).opacity(0.7)
        case .untracked:
            shape.strokeBorder(Theme.txt.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [1, 1.5])).opacity(0.6)
        }
    }

    private func code(_ episode: Episode) -> String {
        EpisodeCode.episode(season: season.seasonNumber, episode: episode.episodeNumber)
    }

    private func statusText(_ episode: Episode, kind: TickKind, now: Date) -> String {
        kind == .untracked ? "Not tracked" : episode.status(editionId: edition.id, now: now).statusText
    }

    private func accessibility(_ episode: Episode, kind: TickKind, now: Date) -> String {
        let st = statusText(episode, kind: kind, now: now)
        if let versionLabel { return "\(code(episode)) · \(versionLabel) · \(st)" }
        return "\(code(episode)) \(episode.title ?? "Episode \(episode.episodeNumber)") · \(st)"
    }

    private func tooltip(_ episode: Episode, kind: TickKind, now: Date) -> some View {
        let quality = episode.file(for: edition.id).map { DetailText.quality($0.quality) }
        let dot: MonoToken? = switch kind {
        case .owned: .done
        case .grab: .grab
        case .want: .miss
        case .soon: .unaired
        case .untracked: nil
        }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(code(episode)).font(.system(size: 12, weight: .bold, design: .monospaced))
                HStack(spacing: 5) {
                    Group {
                        if let dot { StatusSwatch(token: dot, shape: RoundedRectangle(cornerRadius: 2)) } else { RoundedRectangle(cornerRadius: 2).fill(Theme.dim) }
                    }
                    .frame(width: 8, height: 8)
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
