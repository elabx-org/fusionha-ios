import SwiftUI
import FusionhaKit

/// One airing (`.urow`): poster, title with Premiere / "2 eps" chips, the
/// episode line, one upcoming rail per wanted tier, and the air time with a
/// live countdown. The very next airing carries a solid "upcoming" wash.
struct ComingUpRow: View {
    let row: ComingRow
    let now: Date
    var compact = false
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.open(row.itemId) } label: {
            HStack(alignment: .center, spacing: compact ? 10 : 12) {
                ActPoster(url: row.posterUrl, title: row.title, size: .md)
                main
                when
            }
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 9 : 8)
            .frame(minHeight: compact ? 72 : 66)
            .background(row.next ? Theme.unaired.opacity(0.09) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title) \(row.se), airs \(clock), will grab \(row.tiers.map(\.pill).joined(separator: " and "))")
        .accessibilityAddTraits(.isButton)
    }

    private var clock: String { row.air.formatted(date: .omitted, time: .shortened) }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Text(row.title)
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                    .lineLimit(1).truncationMode(.tail)
                if row.premiere { chip("Premiere", Theme.premiere) }
                if row.count > 1 { chip("\(row.count) eps", Theme.mut) }
            }
            (Text(row.se + "  ").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(Theme.txt)
             + Text(row.episodeTitle).font(.system(size: 11.5)).foregroundColor(Theme.mut))
                .lineLimit(1).truncationMode(.tail)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(row.tiers, id: \.self) { tier in
                    RailRowView(rail: Rail(state: .upcoming, progress: 0, fraction: nil, attention: false, deadLinkOnly: false),
                                tier: tier)
                }
            }
            .frame(maxWidth: compact ? .infinity : 340, alignment: .leading)
            .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var when: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(clock)
                .font(.system(size: compact ? 13 : 14, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Theme.txt)
            Text(IdleTime.until(row.air, now: now))
                .font(.system(size: 11, weight: row.next ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(row.next ? Theme.unaired : Theme.dim)
        }
        .lineLimit(1)
        .fixedSize()
        .frame(minWidth: compact ? 58 : 74, alignment: .trailing)
    }

    private func chip(_ text: String, _ tone: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(tone)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tone.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}
