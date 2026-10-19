import SwiftUI
import FusionhaKit

/// A user's UHD·4K requestability and its source (web `UhdChip`): a tinted
/// pill (the 4K colour or grey), never a border. Touch and hold for the reason.
struct UsersUhdChip: View {
    let chip: UsersUHD.Chip
    let uhd: Bool
    var plex = false

    var body: some View {
        let color = uhd ? Theme.cyan : Theme.dim
        HStack(spacing: 4) {
            if plex { Image(systemName: "play.fill").font(.system(size: 8, weight: .bold)) }
            Text(chip.label).font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(uhd ? Theme.txt : Theme.mut)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(uhd ? 0.2 : 0.14), in: Capsule())
        .fixedSize()
        .contextMenu { Text(chip.title) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("UHD·4K access: \(chip.label). \(chip.title)")
    }
}

extension UsersUhdChip {
    init(access: UserTierAccess) {
        self.init(chip: UsersUHD.chip(access), uhd: access.uhd, plex: access.source == "plex")
    }
}

/// The note above the list (web `UsersUhdBanner`): derivation off, or on with
/// no library marked 4K. A status wash, never a border.
struct UsersUhdBanner: View {
    let state: UsersUHD.Banner

    var body: some View {
        let off = state == .off
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: off ? "info.circle" : "exclamationmark.triangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(off ? Theme.dim : Theme.stuck)
                VStack(alignment: .leading, spacing: 3) {
                    Text(off ? "Plex-derived UHD·4K access is off."
                             : "Plex 4K access is on but no Plex library is marked 4K")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                    Text(off ? "Everyone without a manual grant can request every version, so their chip reads “All versions”."
                             : "Plex friends and managed profiles show “HD only · from Plex” until a library counts as 4K.")
                        .font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
            }
            if off {
                NavigationLink {
                    PlexServerSettingsPanel()
                } label: {
                    Text("Open Plex server settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accentText)
                }
                .padding(.leading, 25)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actWash(off ? Theme.dim : Theme.stuck, radius: 12)
    }
}

/// The "UHD·4K source" legend: one chip per source, then the precedence.
struct UsersUhdLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UHD·4K source").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { chips }
                VStack(alignment: .leading, spacing: 4) { chips }
            }
            Text(UsersUHD.legendOrder).font(.system(size: 11)).foregroundStyle(Theme.dim)
        }
        .textCase(nil)
    }

    @ViewBuilder private var chips: some View {
        ForEach(Array(UsersUHD.legend.enumerated()), id: \.offset) { i, chip in
            UsersUhdChip(chip: chip, uhd: true, plex: i == 1)
        }
    }
}
