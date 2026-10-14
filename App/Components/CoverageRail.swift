import SwiftUI
import FusionhaKit

// MARK: Coverage rails (CoverageRail.tsx)
//
// One rail per version: edition chip, a 4pt bar, then the count and a status
// mark (✓ owned, ↓ downloading, ↑ upgrading). Rails are content: never glass.

/// `library_rail_style` (Settings → Library): the full rail, the bar only, or a
/// trailing dot.
enum RailStyle: String, CaseIterable, Sendable {
    case current, fill, dot

    var label: String {
        switch self {
        case .current: return "Current"
        case .fill: return "Fill only"
        case .dot: return "Trailing dot"
        }
    }

    var hint: String {
        switch self {
        case .current: return "Tier, bar and a status glyph or count."
        case .fill: return "Just the bar, with the size or count."
        case .dot: return "The bar with a coloured status dot."
        }
    }
}

private struct RailStyleKey: EnvironmentKey {
    static let defaultValue: RailStyle = .current
}

private struct RailConsolidateKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var railStyle: RailStyle {
        get { self[RailStyleKey.self] }
        set { self[RailStyleKey.self] = newValue }
    }
    var railConsolidate: Bool {
        get { self[RailConsolidateKey.self] }
        set { self[RailConsolidateKey.self] = newValue }
    }
}

/// One edition's `[tier pill] [fill bar] [meta]` row (CoverageRail.tsx).
struct CoverageRailView: View {
    let edition: Edition
    let isSeries: Bool
    var itemUpcoming = false
    var itemUpcomingDate: String? = nil
    var inline = false

    var body: some View {
        RailRowView(rail: edition.rail(isSeries: isSeries, itemUpcoming: itemUpcoming, itemUpcomingDate: itemUpcomingDate),
                    tier: edition.tier, size: edition.size ?? 0, inline: inline)
    }
}

/// Every rail of a title, consolidating complete HD + 4K pairs into one
/// "HD·4K" rail when the library setting asks for it (rail-consolidate.ts).
struct CoverageRails: View {
    let item: MediaItem
    var inline = false
    var spacing: CGFloat = 4
    @Environment(\.railConsolidate) private var consolidate

    var body: some View {
        let rails = item.rails
        let units = Self.units(item: item, rails: rails, consolidate: consolidate)
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(units.indices, id: \.self) { i in
                let unit = units[i]
                if let mate = unit.mate {
                    RailRowView(rail: combo(rails[unit.index], rails[mate]), tier: .hd,
                                size: (item.editions[unit.index].size ?? 0) + (item.editions[mate].size ?? 0),
                                combo: true, inline: inline)
                } else {
                    RailRowView(rail: rails[unit.index], tier: item.editions[unit.index].tier,
                                size: item.editions[unit.index].size ?? 0, inline: inline)
                }
            }
        }
    }

    private func combo(_ a: Rail, _ b: Rail) -> Rail {
        let fraction: String?
        if item.kind == .series {
            let haves = item.editions.map { $0.have ?? 0 }.reduce(0, +)
            let totals = item.editions.map { $0.total ?? 0 }.reduce(0, +)
            fraction = "\(haves)/\(totals)"
        } else {
            fraction = nil
        }
        return Rail(state: .owned, progress: 100, fraction: fraction, attention: false, deadLinkOnly: false)
    }

    struct Unit { let index: Int; let mate: Int? }

    static func units(item: MediaItem, rails: [Rail], consolidate: Bool) -> [Unit] {
        guard consolidate else { return rails.indices.map { Unit(index: $0, mate: nil) } }
        func complete(_ i: Int) -> Bool { rails[i].state == .owned && !rails[i].attention }
        var consumed = Set<Int>()
        var units: [Unit] = []
        for i in rails.indices where !consumed.contains(i) {
            if complete(i) {
                let ed = item.editions[i]
                let mate = rails.indices.first { j in
                    j != i && !consumed.contains(j) && item.editions[j].tier != ed.tier
                        && item.editions[j].movieEdition == ed.movieEdition && complete(j)
                }
                if let mate {
                    consumed.insert(i)
                    consumed.insert(mate)
                    let hdFirst = ed.tier == .hd
                    units.append(Unit(index: hdFirst ? i : mate, mate: hdFirst ? mate : i))
                    continue
                }
            }
            consumed.insert(i)
            units.append(Unit(index: i, mate: nil))
        }
        return units
    }
}

/// A rail from a precomputed `Rail` (grid auto 1fr auto, gap 8; inline auto 54 auto, gap 7).
struct RailRowView: View {
    let rail: Rail
    let tier: QualityTier
    var size: Double = 0
    var combo = false
    var inline = false
    @Environment(\.railStyle) private var style

    var body: some View {
        let color = rail.attention ? (rail.deadLinkOnly ? Theme.stuck : Theme.miss) : rail.state.color
        HStack(spacing: inline ? 7 : 6) {
            if combo { TierComboPill() } else { TierPill(tier: tier) }
            RailBar(progress: rail.progress, color: color, state: rail.state, attention: rail.attention, combo: combo)
                .frame(width: inline ? 54 : nil)
            meta(color: color)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(rail.upcomingEstimated ? Theme.mut : color)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(combo ? "HD and 4K" : tier.chipLabel), \(rail.state.rawValue)\(rail.fraction.map { ", \($0)" } ?? "")")
    }

    @ViewBuilder
    private func meta(color: Color) -> some View {
        if rail.attention {
            Image(systemName: rail.deadLinkOnly ? "link" : "exclamationmark.triangle")
                .font(.system(size: 10, weight: .semibold))
        } else {
            switch rail.state {
            case .upcoming:
                HStack(spacing: 4) {
                    Image(systemName: rail.upcomingStage == "digital" ? "tv"
                          : rail.upcomingStage == "physical" ? "opticaldisc" : "clock")
                        .font(.system(size: 10, weight: .semibold))
                    if let date = rail.upcomingDate {
                        Text((rail.upcomingEstimated ? "~" : "") + Format.releaseDate(date))
                    } else {
                        Text("Upcoming")
                    }
                }
            case .upgrading:
                HStack(spacing: 4) {
                    if let f = rail.fraction { Text(f) }
                    Image(systemName: "arrow.up").font(.system(size: 10, weight: .bold))
                }
            case .downloading:
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 10, weight: .bold))
                    if style == .current {
                        if let f = rail.fraction { Text(f) }
                    } else {
                        Text("\(rail.progress)%")
                    }
                }
            case .owned:
                switch style {
                case .fill: Text(rail.fraction ?? Format.bytes(size))
                case .dot: Circle().fill(color).frame(width: 8, height: 8)
                case .current:
                    HStack(spacing: 4) {
                        if let f = rail.fraction { Text(f) }
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy))
                    }
                }
            case .partial, .wanted:
                switch style {
                case .fill: if let f = rail.fraction { Text(f) }
                case .dot: Circle().fill(color).frame(width: 8, height: 8)
                case .current: Text(rail.fraction ?? "Wanted")
                }
            }
        }
    }
}

/// The 4pt rounded rail track with its status fill: diagonal blue stripes for
/// upcoming, a cyan gradient with a white sweep while downloading.
struct RailBar: View {
    let progress: Int
    let color: Color
    var state: RailState = .owned
    var attention = false
    var combo = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if state == .upcoming && !attention {
                    Stripes(color: Theme.unaired.opacity(0.22))
                } else {
                    Capsule().fill(Theme.txt.opacity(0.1))
                }
                fill.frame(width: geo.size.width * CGFloat(progress) / 100)
                if state == .downloading && !attention && !reduceMotion {
                    Sweep(width: geo.size.width)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private var fill: some View {
        if combo {
            Capsule().fill(LinearGradient(colors: [Theme.edition, Theme.grab], startPoint: .leading, endPoint: .trailing))
        } else if state == .downloading && !attention {
            Capsule().fill(LinearGradient(colors: [Theme.grab, Theme.grab.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
        } else {
            Capsule().fill(color)
        }
    }
}

/// `repeating-linear-gradient(90deg, c 0 6px, transparent 6px 12px)`.
private struct Stripes: View {
    let color: Color
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: 6, height: size.height)), with: .color(color))
                x += 12
            }
        }
    }
}

/// The 1.5s white sweep across a downloading bar (render-loop driven, see `RepeatForever`).
private struct Sweep: View {
    let width: CGFloat
    var body: some View {
        RepeatForever(animation: .timingCurve(0.2, 0.6, 0.35, 1, duration: 1.5).repeatForever(autoreverses: false)) { on in
            LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: width * 0.38)
                .offset(x: -width * 0.4 + (on ? width * 1.4 : 0))
        }
        .allowsHitTesting(false)
    }
}

