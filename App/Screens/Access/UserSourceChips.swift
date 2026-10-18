import SwiftUI
import FusionhaKit

/// A Users-list row's automatic sources (web `WatchlistChip` +
/// `LetterboxdChip`): one pill per source the person has, the filter's word
/// for it and its state in the state's tone ("Watchlist · Healthy · 3
/// sources"). Sources that don't exist for them (not allowed, not
/// connected, password-only) show nothing; the Show filter finds people by
/// source. Display only: the row opens the account sheet, whose Automatic
/// requests section opens the status.
struct UserSourceChips: View {
    let plex: PlexWatchlistSummaryRow?
    let letterboxd: LetterboxdSummaryRow?

    static let hiddenPlex: Set<String> = ["not_allowed", "ineligible", "plex_only"]
    static let hiddenLetterboxd: Set<String> = ["not_connected", "not_allowed"]

    private var pills: [(word: String, state: String, tone: SourceAdminCopy.Tone, symbol: String)] {
        var out: [(String, String, SourceAdminCopy.Tone, String)] = []
        if let plex, !Self.hiddenPlex.contains(plex.state) {
            out.append(("Watchlist", SourceAdminCopy.plexChipLabel(plex), SourceAdminCopy.plexChip(plex.state).tone, Self.symbol(plex.state)))
        }
        if let letterboxd, !Self.hiddenLetterboxd.contains(letterboxd.state) {
            out.append(("Letterboxd", SourceAdminCopy.letterboxdChipLabel(letterboxd), SourceAdminCopy.letterboxdTone(letterboxd.state), Self.symbol(letterboxd.state)))
        }
        return out
    }

    /// "23 auto-requested" across both sources, for the row's meta line.
    static func requestedLine(plex: PlexWatchlistSummaryRow?, letterboxd: LetterboxdSummaryRow?) -> String? {
        let n = (plex?.requestedCount ?? 0) + (letterboxd?.requestedCount ?? 0)
        return n > 0 ? "\(n) auto-requested" : nil
    }

    var body: some View {
        let pills = pills
        if !pills.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { ForEach(pills, id: \.word) { pill($0.word, $0.state, $0.tone, $0.symbol) } }
                VStack(alignment: .leading, spacing: 4) { ForEach(pills, id: \.word) { pill($0.word, $0.state, $0.tone, $0.symbol) } }
            }
            .padding(.top, 4)
        }
    }

    /// The state as a shape too, so it survives Monochrome and colour blindness.
    static func symbol(_ state: String) -> String {
        switch state {
        case "healthy": return "checkmark.circle.fill"
        case "checking": return "arrow.triangle.2.circlepath"
        case "paused": return "pause.circle.fill"
        case "allowed_off": return "minus.circle"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private func pill(_ word: String, _ state: String, _ tone: SourceAdminCopy.Tone, _ symbol: String) -> some View {
        let quiet = tone == .dim
        return (Text(Image(systemName: symbol)).foregroundColor(quiet ? Theme.mut : tone.color) + Text(" ")
                + Text(word).fontWeight(.semibold).foregroundColor(Theme.txt)
                + Text(" · \(state)").foregroundColor(quiet ? Theme.mut : tone.color))
            .font(.system(size: 12))
            .lineLimit(1)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background((quiet ? Theme.mut : tone.color).opacity(0.12), in: Capsule())
            .accessibilityLabel("\(word == "Watchlist" ? "Plex watchlist" : word): \(state)")
    }
}
