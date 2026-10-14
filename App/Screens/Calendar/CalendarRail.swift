import SwiftUI
import FusionhaKit

// MARK: Edition rail (`RailBar` / `CalendarRail`)

enum CalRailMeta: Hashable {
    case check
    case down
    case wanted
    case soon
    /// A season drop: `2/3`, plus a check when complete or ↓ while grabbing.
    case count(String, complete: Bool, grabbing: Bool)
}

struct CalRailModel: Hashable {
    let tier: QualityTier
    let color: Color
    let statusLabel: String
    /// 0…1 fill; striped tracks (wanted / unaired) have no fill.
    let fill: Double
    let striped: Bool
    let downloading: Bool
    let meta: CalRailMeta

    /// One edition of an entry, unaired-aware.
    init(entry: CalendarEntry, edition: CalendarEdition, now: Date) {
        let key = entry.statusKey(for: edition, now: now)
        tier = edition.tier
        color = key.color
        statusLabel = key.label
        switch key {
        case .downloaded: fill = 1; striped = false; downloading = false; meta = .check
        case .downloading: fill = 0.45; striped = false; downloading = true; meta = .down
        case .missing: fill = 0; striped = true; downloading = false; meta = .wanted
        case .unaired: fill = 0; striped = true; downloading = false; meta = .soon
        }
    }

    /// A season drop's per-tier aggregate.
    init(season: SeasonTierAggregate) {
        tier = season.tier
        let complete = season.done == season.total
        let key: CalendarStatusKey = complete ? .downloaded : (season.grabbing > 0 ? .downloading : .missing)
        color = key.color
        statusLabel = key.label
        let ratio = season.total > 0 ? Double(season.done) / Double(season.total) : 0
        fill = complete ? 1 : ratio
        striped = key == .missing
        downloading = key == .downloading
        meta = .count("\(season.done)/\(season.total)", complete: complete, grabbing: season.grabbing > 0)
    }
}

/// `[tier chip] [52pt bar] [meta]`. The chip is the lit `TierPill` (HD purple,
/// 4K cyan); `outlinedTier: false` keeps the bare tier text for tight cards.
struct CalRail: View {
    let rail: CalRailModel
    var outlinedTier = true
    var metaSize: CGFloat = 9

    var body: some View {
        HStack(spacing: 6) {
            if outlinedTier {
                TierPill(tier: rail.tier)
            } else {
                Text(rail.tier.pill)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(rail.tier.color)
            }
            CalRailBar(rail: rail)
                .frame(width: 52, height: 5)
            meta
                .font(.system(size: metaSize, weight: .bold, design: .monospaced))
                .foregroundStyle(rail.color)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rail.tier.chipLabel) \(rail.statusLabel)")
    }

    @ViewBuilder
    private var meta: some View {
        switch rail.meta {
        case .check:
            Image(systemName: "checkmark").font(.system(size: metaSize + 1, weight: .heavy))
        case .down:
            Text("↓")
        case .wanted:
            Text("wanted")
        case .soon:
            HStack(spacing: 2) {
                Image(systemName: "clock").font(.system(size: 9, weight: .bold))
                Text("soon")
            }
        case .count(let text, let complete, let grabbing):
            HStack(spacing: 2) {
                Text(text)
                if complete {
                    Image(systemName: "checkmark").font(.system(size: metaSize + 1, weight: .heavy))
                } else if grabbing {
                    Text("↓")
                }
            }
        }
    }
}

struct CalRailBar: View {
    let rail: CalRailModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calMotionOff) private var motionOff
    @State private var sweep = false
    /// `.rfill` grows to its width over 0.9s (REVEAL_EASE).
    @State private var grown = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                if rail.striped {
                    Canvas { context, size in
                        var x: CGFloat = 0
                        while x < size.width {
                            context.fill(Path(CGRect(x: x, y: 0, width: 5, height: size.height)),
                                         with: .color(rail.color.opacity(0.3)))
                            x += 10
                        }
                    }
                } else {
                    Rectangle().fill(Theme.txt.opacity(0.1))
                    Rectangle().fill(rail.color).frame(width: w * (grown || reduceMotion || motionOff ? rail.fill : 0))
                        .clipShape(Capsule())
                }
                if rail.downloading && !reduceMotion && !motionOff {
                    LinearGradient(colors: [.clear, .white.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: w * 0.38)
                        .offset(x: sweep ? w : -w * 0.4)
                        .onAppear {
                            withAnimation(.timingCurve(0.52, 0.01, 0.16, 1, duration: 1.5).repeatForever(autoreverses: false)) {
                                sweep = true
                            }
                        }
                }
            }
        }
        .clipShape(Capsule())
        .onAppear {
            guard !grown else { return }
            if reduceMotion || motionOff { grown = true } else {
                withAnimation(CalMotion.reveal(duration: 0.9)) { grown = true }
            }
        }
    }
}
