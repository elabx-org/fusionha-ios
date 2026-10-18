import SwiftUI
import FusionhaKit

struct HistoryRow: View {
    let entry: HistoryEntry

    private var color: Color {
        let type = entry.eventType.uppercased()
        if type.contains("FAIL") || type.contains("DELETE") || type.contains("REJECT") { return Theme.danger }
        if type.contains("IMPORT") || type.contains("DOWNLOADED") { return Theme.done }
        if type.contains("GRAB") { return Theme.grab }
        if type.contains("UPGRADE") { return Theme.edition }
        return Theme.mut
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(url: TMDBImage.resized(entry.posterUrl, to: "w154"))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.itemTitle ?? "Unknown title")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if let tier = entry.tier { TierPill(tier: tier) }
                    Spacer(minLength: 0)
                    Text(Format.relative(entry.createdAt))
                        .font(.system(size: 11)).foregroundStyle(Theme.dim).lineLimit(1)
                }
                Text(entry.eventLabel)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(color)
                // A HELD step names its hold in the server's shared words (0.4.203).
                if let held = entry.held {
                    Text(held.stepTitle)
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.miss)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let source = entry.sourceTitle {
                    Text(source)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(2)
                }
                if let chips = entry.chips, !chips.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.mut)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 5))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))
                        }
                    }
                }
            }
        }
        .padding(12)
        .panel(Theme.card, radius: 14)
        .contentShape(Rectangle())
    }
}
