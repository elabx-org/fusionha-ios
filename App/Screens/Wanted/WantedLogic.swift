import SwiftUI
import FusionhaKit

enum WantedTab: String, CaseIterable, Hashable {
    case missing, cutoff, upcoming, fourk = "4k"

    var state: WantedState? {
        switch self {
        case .missing: return .missing
        case .cutoff: return .cutoffUnmet
        case .upcoming: return .upcoming
        case .fourk: return nil
        }
    }

    var label: String {
        switch self {
        case .missing: return "Missing"
        case .cutoff: return "Cutoff Unmet"
        case .upcoming: return "Upcoming"
        case .fourk: return "4K Available"
        }
    }

    var accent: Color {
        switch self {
        case .missing: return Theme.miss
        case .cutoff: return Theme.edition
        case .upcoming: return Theme.unaired
        case .fourk: return QualityTier.uhd.color
        }
    }

    var noun: String {
        switch self {
        case .missing: return "missing"
        case .cutoff: return "below cutoff"
        case .upcoming: return "upcoming"
        case .fourk: return "4K-available titles"
        }
    }

    var emptyMessage: String {
        switch self {
        case .missing: return "Nothing missing — every released or aired monitored version has a file."
        case .cutoff: return "Nothing below cutoff — every monitored file meets its profile cutoff."
        case .upcoming, .fourk: return "Nothing upcoming — no monitored version is waiting on a release or an air date."
        }
    }
}

/// The web's per-edition state vocabulary on the Wanted wire.
enum WantedLogic {
    static func stateColor(_ state: String) -> Color {
        switch state {
        case "missing": return Theme.miss
        case "cutoff_unmet": return Theme.edition
        case "upcoming": return Theme.unaired
        default: return Theme.done
        }
    }

    static func stateLabel(_ state: String) -> String {
        switch state {
        case "missing": return "Missing"
        case "cutoff_unmet": return "Cutoff unmet"
        case "upcoming": return "Upcoming"
        default: return "Have"
        }
    }

    static func kind(isAnime: Bool, kind: MediaKind) -> String {
        isAnime ? "anime" : (kind == .movie ? "movie" : "series")
    }

    static func primaryEdition(_ item: WantedItem, _ tab: WantedTab) -> WantedEdition? {
        item.editions.first { $0.state == tab.state?.rawValue } ?? item.editions.first
    }

    /// `contextCue`: the one fact that explains why this title is wanted.
    static func cue(_ item: WantedItem, _ e: WantedEdition) -> String {
        if e.state == "cutoff_unmet", let q = e.currentQuality { return "have \(ActFmt.quality(q))" }
        if item.kind == .movie {
            if e.state == "upcoming" {
                return e.upcomingUntil.map { "Upcoming until \(ActFmt.releaseDate($0))" } ?? "Upcoming"
            }
            if let released = e.releasedAt { return "Released \(ActFmt.relative(released))" }
            return lastSearch(e)
        }
        if e.state == "upcoming" { return "Next episode not yet aired" }
        let count = e.missingEpisodeCount ?? 0
        if count > 0 {
            let noun = count == 1 ? "episode" : "episodes"
            if let latest = e.latestAired { return "\(count) \(noun) aired · latest \(ActFmt.relative(latest))" }
            return "\(count) \(noun) aired"
        }
        return lastSearch(e)
    }

    private static func lastSearch(_ e: WantedEdition) -> String {
        e.lastSearch.map { "last search \(ActFmt.relative($0))" } ?? "never searched"
    }
}

/// The kind pill (`.kind[data-kind]`), 9.5/800 uppercase capsule.
struct WantedKindPill: View {
    let kind: String

    var body: some View {
        let tint: Color = kind == "movie" ? Theme.indigo : (kind == "series" ? Theme.cyan : Theme.anime)
        let text: Color = kind == "anime" ? Theme.anime : tint.mix(with: Theme.txt, by: kind == "movie" ? 0.4 : 0.38)
        Text(kind.uppercased())
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tint.opacity(kind == "movie" ? 0.14 : 0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(kind == "series" ? 0.32 : 0.34)))
            .fixedSize()
    }
}
