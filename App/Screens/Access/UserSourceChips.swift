import SwiftUI
import FusionhaKit

/// A Users-list row's automatic-source chips (web `WatchlistChip` +
/// `LetterboxdChip`): a dot in the state's tone and its label, with
/// "N requested · …" once something was requested. Display only: the row
/// opens the account sheet, whose Automatic requests section opens the status.
struct UserSourceChips: View {
    let plex: PlexWatchlistSummaryRow?
    let letterboxd: LetterboxdSummaryRow?

    var body: some View {
        if plex != nil || letterboxd != nil {
            VStack(alignment: .leading, spacing: 3) {
                if let plex {
                    chip(kind: "PLEX_WATCHLIST", provider: "Plex watchlist", label: SourceAdminCopy.plexChipLabel(plex),
                         tone: SourceAdminCopy.plexChip(plex.state).tone,
                         hint: plex.requestedCount > 0 ? plexHint(plex) : nil)
                }
                if let letterboxd {
                    chip(kind: "LETTERBOXD_RSS", provider: "Letterboxd", label: SourceAdminCopy.letterboxdChipLabel(letterboxd),
                         tone: SourceAdminCopy.letterboxdTone(letterboxd.state), hint: SourceAdminCopy.letterboxdHint(letterboxd))
                }
            }
            .padding(.top, 2)
        }
    }

    private func plexHint(_ row: PlexWatchlistSummaryRow) -> String {
        "\(row.requestedCount) requested" + (row.lastCheckedAt.map { " · checked \(ActFmt.relative($0))" } ?? "")
    }

    private func chip(kind: String, provider: String, label: String, tone: SourceAdminCopy.Tone, hint: String?) -> some View {
        HStack(spacing: 5) {
            RequestSourceGlyph(kind: kind, size: 9)
            Circle().fill(tone.color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(tone == .dim ? Theme.mut : Theme.txt)
            if let hint { Text(hint).font(.system(size: 11)).foregroundStyle(Theme.dim) }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(provider): \(label)" + (hint.map { ", \($0)" } ?? ""))
    }
}
