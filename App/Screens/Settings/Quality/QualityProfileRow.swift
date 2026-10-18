import SwiftUI
import FusionhaKit

/// One profile in the list (web `ProfileCard`): name, kind chip, custom-format
/// count, badges (Default slots · TRaSH · items in use), the SD / HD / FHD / UHD
/// ladder with the cutoff rung flagged, and the upgrade-until / min-score line.
struct QualityProfileRow: View {
    let profile: QualityProfileRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(profile.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                kindChip
                Spacer(minLength: 0)
                let cf = profile.formatScores.count
                Text(cf == 0 ? "no CF" : "+\(cf) CF")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(cf == 0 ? Theme.dim : Theme.done)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.dim)
            }
            badges
            rungs
            Text("Upgrade until **\(DetailText.quality(profile.upgradeUntil ?? profile.cutoff))** · min score **\(profile.minFormatScore)**")
                .font(.caption).foregroundStyle(Theme.mut)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var kindColor: Color {
        switch profile.mediaKind {
        case "movie": return Theme.kindMovie
        case "series": return Theme.kindSeries
        case "anime": return Theme.kindAnime
        default: return Theme.mut
        }
    }

    private var kindChip: some View {
        let color = kindColor
        return Text(QualityProfileKinds.label(profile.mediaKind))
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    private var badges: some View {
        let inUse = profile.inUse ?? 0
        return HStack(spacing: 6) {
            ForEach(profile.defaultFor ?? [], id: \.self) { slot in
                badge(QualityProfileKinds.defaultBadge(slot), Theme.done)
            }
            if profile.source == "trash" { badge("TRaSH", Theme.i2) }
            badge(inUse > 0 ? "\(inUse) \(inUse == 1 ? "item" : "items")" : "unused", Theme.mut)
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
    }

    private var rungs: some View {
        HStack(spacing: 4) {
            ForEach(QualityProfileRungs.derive(allowed: profile.allowedQualities, cutoff: profile.cutoff)) { rung in
                VStack(spacing: 1) {
                    Text(rung.tier).font(.caption2.weight(.bold))
                    Text(rung.resolution).font(.system(size: 11).monospacedDigit())
                }
                .foregroundStyle(rung.allowed ? Theme.txt : Theme.dim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(rung.allowed ? Theme.i1.opacity(0.18) : Theme.panel2,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(rung.isCutoff ? Theme.done : .clear, lineWidth: 1.5))
                .accessibilityElement(children: .combine)
                .accessibilityValue(rung.isCutoff ? "Upgrade until" : (rung.allowed ? "Allowed" : "Not allowed"))
            }
        }
        .accessibilityLabel("Quality ladder")
    }
}
