import SwiftUI
import FusionhaKit

/// A person's automatic request sources on their account sheet (web Users
/// list `WatchlistChip` + `LetterboxdChip`, fusionha 0.4.209 / 0.4.213): one
/// row per provider with its state chip, opening the read-only status. Read
/// from the Users summaries (`/users/plex-watchlist/summary`,
/// `/users/letterboxd/summary`).
struct UserSourcesSection: View {
    let user: UserAccount
    @Environment(AppModel.self) private var model
    @State private var plex: PlexWatchlistSummaryRow?
    @State private var letterboxd: LetterboxdSummaryRow?

    @State private var loaded = false

    var body: some View {
        Section("Automatic requests") {
            if let plex { plexRow(plex) }
            if let letterboxd { letterboxdRow(letterboxd) }
            if !loaded {
                ProgressView()
            } else if plex == nil && letterboxd == nil {
                Text("This server doesn’t report automatic request sources.").font(.footnote).foregroundStyle(Theme.mut)
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func plexRow(_ row: PlexWatchlistSummaryRow) -> some View {
        let chip = SourceAdminCopy.plexChip(row.state)
        let label = providerLabel("Plex watchlist & lists", detail: row.requestedCount > 0 ? "\(row.requestedCount) requested" : nil,
                                  pill: SourceAdminCopy.plexChipLabel(row), tone: chip.tone)
        if chip.opens {
            NavigationLink { PlexWatchlistStatusView(userId: user.id, name: user.displayName, row: row) } label: { label }
        } else {
            label
        }
    }

    @ViewBuilder
    private func letterboxdRow(_ row: LetterboxdSummaryRow) -> some View {
        let label = providerLabel("Letterboxd", detail: row.username.map { "@\($0)" },
                                  pill: SourceAdminCopy.letterboxdChipLabel(row), tone: SourceAdminCopy.letterboxdTone(row.state))
        if SourceAdminCopy.letterboxdOpens(row.state) {
            NavigationLink { LetterboxdStatusView(userId: user.id, name: user.displayName, row: row) } label: { label }
        } else {
            label
        }
    }

    private func providerLabel(_ title: String, detail: String?, pill: String, tone: SourceAdminCopy.Tone) -> some View {
        HStack(spacing: 10) {
            RequestSourceGlyph(kind: title == "Letterboxd" ? "LETTERBOXD_RSS" : "PLEX_WATCHLIST", size: 14)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                if let detail { Text(detail).font(.caption).foregroundStyle(Theme.mut) }
            }
            Spacer(minLength: 6)
            SourceStatePill(label: pill, tone: tone)
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        async let plexCall = try? client.plexWatchlistSummary()
        async let lbCall = try? client.letterboxdSummary()
        let plexRows = await plexCall
        let lbRows = await lbCall
        let id = user.id
        plex = plexRows?.first(where: { $0.userId == id })
        letterboxd = lbRows?.first(where: { $0.userId == id })
        loaded = true
    }
}
