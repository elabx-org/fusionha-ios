import SwiftUI
import FusionhaKit

/// One raw History event (mock activity-log.js `rawRows`): the time, the
/// event as a small pill, the title and what it was. On the open Duo the
/// log runs across the whole display and the custom-format score gets a
/// column (`wide`). A failure's pill is the danger ink; the rest are one ink.
struct V2HistoryRawRow: View {
    let entry: HistoryEntry
    var wide = false
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        HStack(spacing: 10) {
            Text(V2QueueTime.clock(entry.createdAt) ?? ActFmt.relative(entry.createdAt))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(muted)
                .frame(width: 44, alignment: .leading)
            pill.frame(width: 92)
            if wide {
                Text(entry.itemTitle ?? "Unknown").font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
                    .lineLimit(1).frame(width: 230, alignment: .leading)
                Text(detail).font(.system(size: 11.5)).foregroundStyle(muted).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(entry.cfScore.map { "\($0 >= 0 ? "+" : "")\($0.formatted())" } ?? "")
                    .font(.system(size: 11.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(ink)
                    .frame(width: 64, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.itemTitle ?? "Unknown").font(.system(size: 13, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var failed: Bool { HistoryLogic.rawFilter(entry.eventType) == "failed" }

    private var pill: some View {
        let meta = HistoryLogic.eventMeta(entry.eventType)
        let tint = failed ? Theme.dangerText : (entry.eventType == "DELETED" ? muted : ink)
        return Text(meta.label.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.3)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    /// "HD · CiNEPHiLES Remux · NzbNest" from what the event carries.
    private var detail: String {
        var parts: [String] = []
        if let tier = entry.tier { parts.append(tier.badgeLetters) }
        if let quality = entry.quality { parts.append(ActFmt.quality(quality)) }
        if let release = entry.sourceTitle { parts.append(release) }
        if let indexer = entry.indexer { parts.append(indexer) }
        if !wide, let size = entry.size { parts.append(ActFmt.bytes(size)) }
        return parts.joined(separator: " · ")
    }
}
