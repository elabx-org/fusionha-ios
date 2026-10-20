import SwiftUI
import FusionhaKit

// Wanted · 4K Available (`FourKCard`, `FourKRail`, `FourKSeasonRow` in
// routes/Wanted.tsx) and its "Add edition" sheet (AddEditionDialog preset to UHD).

private let fourKSourceLabels: [String: String] = [
    "rss": "RSS", "manual": "Manual search", "observed": "Auto search", "probe": "Probe", "check": "Checked",
]

private func fourKSources(_ sources: [String]?, _ source: String?) -> [String] {
    let raw = (sources?.isEmpty == false ? sources : source.map { [$0] }) ?? []
    var out: [String] = []
    for s in raw { if let label = fourKSourceLabels[s], !out.contains(label) { out.append(label) } }
    return out
}

/// The `via RSS + Auto search` provenance pill.
private struct FourKProvenance: View {
    let labels: [String]
    var body: some View {
        Text("via \(labels.joined(separator: " + "))")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(QualityTier.uhd.color.mix(with: Theme.mut, by: 0.25))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(QualityTier.uhd.color.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(QualityTier.uhd.color.opacity(0.24)))
            .lineLimit(1)
            .fixedSize()
    }
}

/// One HD-owned / 4K-available coverage rail; the fill grows in over 0.9s.
private struct FourKRail: View {
    let tier: QualityTier
    let fraction: Double
    let meta: String
    @Environment(\.actReduceMotion) private var reduce
    @State private var grown = false

    var body: some View {
        let rc = tier == .hd ? Theme.done : Theme.grab
        HStack(spacing: 7) {
            Text(tier.pill)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(tier.color)
                .frame(minWidth: 24)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(tier.color.opacity(0.45)))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.txt.opacity(0.07))
                    StatusSwatch(token: tier == .hd ? .done : .grab, shape: Capsule())
                        .frame(width: geo.size.width * fraction * (reduce || grown ? 1 : 0))
                }
            }
            .frame(height: 6)
            HStack(spacing: 4) {
                Image(systemName: tier == .hd ? "checkmark" : "circle.fill").font(.system(size: 8, weight: .heavy))
                Text(meta)
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(rc)
            .lineLimit(1)
            .fixedSize()
        }
        .onAppear {
            guard !reduce, !grown else { return }
            withAnimation(ActMotion.reveal(0.9)) { grown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.chipLabel) \(tier == .hd ? "owned" : "available"), \(meta)")
    }
}

struct WantedFourKCard: View {
    let item: FourKAvailableItem
    let onAdd: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.paneSize) private var pane
    @State private var checking = false

    private func rail(_ tier: QualityTier) -> (Double, String) {
        if let total = item.totalSeasons {
            let have = tier == .hd ? (item.hdOwnedSeasons ?? 0) : (item.uhdAvailableSeasons ?? 0)
            let pct = total > 0 ? min(1, Double(have) / Double(total)) : 0
            return (pct, "\(have) / \(total) season\(total == 1 ? "" : "s")")
        }
        if tier == .hd { return (1, "Owned · 1 file") }
        return (1, "Available · \(ActFmt.plural(item.seenCount, "release"))")
    }

    var body: some View {
        let kind = WantedLogic.kind(isAnime: item.isAnime, kind: item.kind)
        let provenance = fourKSources(item.sources, item.source)
        let hd = rail(.hd)
        let uhd = rail(.uhd)
        ActGroupCard(wash: StatusTone(color: QualityTier.uhd.color, mono: QualityTier.uhd.monoToken), base: Theme.panel, defaultOpen: true, hasTrailing: false) {
            ActPoster(url: item.posterUrl, title: item.title, size: .md)
        } title: {
            ActFlow(spacing: 9, lineSpacing: 4) {
                Text(item.title).font(.system(size: 15, weight: .bold)).tracking(-0.15).foregroundStyle(Theme.txt)
                WantedKindPill(kind: kind)
                Text("4K spotted").font(.system(size: 12.5, weight: .bold)).foregroundStyle(QualityTier.uhd.color)
            }
        } trailing: {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if Double(pane.width) > 760 {
                        // Desktop (web `.fourkBody` above 760): rails and tags on the
                        // left, the sighting meta and actions right-aligned beside them.
                        HStack(alignment: .top, spacing: 22) {
                            left(hd: hd, uhd: uhd).frame(maxWidth: .infinity, alignment: .leading)
                            right(provenance, alignment: .trailing).fixedSize()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            left(hd: hd, uhd: uhd)
                            right(provenance, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)
                if let seasons = item.seasons, !seasons.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(seasons.enumerated()), id: \.element.id) { index, season in
                            if index > 0 {
                                Rectangle().fill(Theme.line).frame(height: 1).mask(
                                    HStack(spacing: 3) { ForEach(0..<120, id: \.self) { _ in Rectangle().frame(width: 3) } })
                            }
                            seasonRow(season)
                        }
                    }
                    .background(Theme.panel2)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
            }
        }
    }

    private func left(hd: (Double, String), uhd: (Double, String)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                FourKRail(tier: .hd, fraction: hd.0, meta: hd.1)
                FourKRail(tier: .uhd, fraction: uhd.0, meta: uhd.1)
            }
            .frame(maxWidth: 230, alignment: .leading)
            if let tags = item.formatTags, !tags.isEmpty {
                ActFlow(spacing: 6, lineSpacing: 6) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in formatTag(tag) }
                }
            }
        }
    }

    private func right(_ provenance: [String], alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(metaLine)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.dim)
            if !provenance.isEmpty { FourKProvenance(labels: provenance) }
            actions.padding(.top, 4)
        }
    }

    private var metaLine: String {
        var parts = [item.seenCount == 1 ? "Seen once" : "Seen \(item.seenCount)×"]
        if let size = item.bestSize, size > 0 { parts.append(ActFmt.bytes(size)) }
        if let last = item.lastSeenAt { parts.append("last \(ActFmt.relative(last))") }
        return parts.joined(separator: " · ")
    }

    private func formatTag(_ tag: FormatTag) -> some View {
        let color: Color = {
            switch tag.kind {
            case "quality": return QualityTier.uhd.color
            case "hdr": return Theme.miss
            case "audio": return Theme.done
            case "group": return Theme.edition
            default: return Theme.mut
            }
        }()
        return Text(tag.label)
            .font(.system(size: 11, weight: .semibold, design: tag.kind == "group" ? .monospaced : .default))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3)))
            .lineLimit(1)
            .fixedSize()
    }

    private var actions: some View {
        HStack(spacing: 6) {
            iconButton(label: "Open in library") {
                Image(systemName: "arrow.up.right.square")
            } action: { model.open(item.id) }
            iconButton(label: "Check for 4K now", busy: checking) {
                Image(systemName: "magnifyingglass")
            } action: { check() }
            Button(action: onAdd) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    Text("Add").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 12)
                .frame(minWidth: 40, minHeight: 40)
                .background(Theme.primary, in: Capsule())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add 4K version")
        }
    }

    private func iconButton<Icon: View>(label: String, busy: Bool = false, @ViewBuilder icon: () -> Icon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if busy { ProgressView().controlSize(.mini).tint(Theme.mut) } else { icon().font(.system(size: 15)) }
            }
            .foregroundStyle(Theme.mut)
            .frame(width: 40, height: 40)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(label)
    }

    private func check() {
        checking = true
        Task {
            defer { checking = false }
            do {
                let result = try await model.client?.activityCheckFourK(itemId: item.id)
                let message = result?.message ?? ""
                toaster.show(message.isEmpty ? "Checked \(item.title) for 4K." : message,
                             tone: result?.foundUhd == true ? .success : .info)
            } catch {
                toaster.error(error)
            }
        }
    }

    private func seasonRow(_ season: FourKSeason) -> some View {
        let sources = fourKSources(nil, season.source)
        return HStack(spacing: 12) {
            Text(String(format: "S%02d", season.seasonNumber))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .frame(minWidth: 58, alignment: .leading)
            Text(season.bestReleaseName ?? "Seen \(season.seenCount)×")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let q = season.bestQuality {
                Text(ActFmt.quality(q)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim).fixedSize()
            }
            if !sources.isEmpty { FourKProvenance(labels: sources) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
