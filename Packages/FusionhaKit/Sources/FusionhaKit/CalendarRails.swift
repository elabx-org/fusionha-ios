import Foundation

// The calendar's rails are the library's coverage rails (web
// `routes/calendar/rails.tsx` → `CoverageRail` + `consolidateVersions`, chips
// from `calendar-chip.ts`): same states, same rail style, and a complete HD +
// 4K pair folds into one HD·4K rail when the library setting asks for it.

/// One rail on a calendar card: a tier's rail, or the consolidated HD·4K pair.
public struct CalendarRailUnit: Sendable, Hashable {
    public let tier: QualityTier
    public let combo: Bool
    public let rail: Rail
}

public enum CalendarRails {
    /// An episode or movie entry, HD first.
    public static func entry(_ e: CalendarEntry, now: Date = Date(), consolidate: Bool) -> [CalendarRailUnit] {
        let rails = e.editions.sorted { $0.tier == .hd && $1.tier != .hd }.map { ed in
            (ed.tier, rail(entry: e, edition: ed, now: now))
        }
        return units(rails, consolidate: consolidate, comboFraction: nil)
    }

    /// A season drop: per tier `done/total`, upcoming only when no episode has aired.
    public static func season(_ g: SeasonGroup, now: Date = Date(), consolidate: Bool) -> [CalendarRailUnit] {
        let upcoming = g.entries.allSatisfy { !$0.hasAired(now: now) }
        let rails = g.tiers.map { ($0.tier, rail(season: $0, upcoming: upcoming)) }
        let done = g.tiers.map(\.done).reduce(0, +), total = g.tiers.map(\.total).reduce(0, +)
        return units(rails, consolidate: consolidate, comboFraction: "\(done)/\(total)")
    }

    static func rail(entry: CalendarEntry, edition: CalendarEdition, now: Date) -> Rail {
        switch entry.statusKey(for: edition, now: now) {
        case .downloaded: return Rail(state: .owned, progress: 100, fraction: nil, attention: false, deadLinkOnly: false)
        case .downloading:
            let pct = edition.progress.map { min(max($0, 0), 100) } ?? 45
            return Rail(state: .downloading, progress: max(pct, 4), fraction: nil, attention: false, deadLinkOnly: false)
        case .missing: return Rail(state: .wanted, progress: 0, fraction: nil, attention: false, deadLinkOnly: false)
        case .unaired: return Rail(state: .upcoming, progress: 0, fraction: nil, attention: false, deadLinkOnly: false)
        }
    }

    static func rail(season t: SeasonTierAggregate, upcoming: Bool) -> Rail {
        let progress = t.total > 0 ? Int((Double(t.done) / Double(t.total) * 100).rounded()) : 0
        let state: RailState
        if t.total > 0 && t.done == t.total { state = .owned }
        else if t.grabbing > 0 { state = .downloading }
        else if t.done > 0 { state = .partial }
        else { state = upcoming ? .upcoming : .wanted }
        return Rail(state: state, progress: progress, fraction: "\(t.done)/\(t.total)", attention: false, deadLinkOnly: false)
    }

    /// `consolidateVersions`: a complete HD rail and a complete 4K rail become one.
    static func units(_ rails: [(QualityTier, Rail)], consolidate: Bool, comboFraction: String?) -> [CalendarRailUnit] {
        let plain = rails.map { CalendarRailUnit(tier: $0.0, combo: false, rail: $0.1) }
        guard consolidate,
              let hd = rails.firstIndex(where: { $0.0 == .hd && $0.1.state == .owned }),
              let uhd = rails.firstIndex(where: { $0.0 == .uhd && $0.1.state == .owned }) else { return plain }
        var out = plain
        let combo = CalendarRailUnit(tier: .hd, combo: true,
                                     rail: Rail(state: .owned, progress: 100, fraction: comboFraction, attention: false, deadLinkOnly: false))
        out[min(hd, uhd)] = combo
        out.remove(at: max(hd, uhd))
        return out
    }
}
