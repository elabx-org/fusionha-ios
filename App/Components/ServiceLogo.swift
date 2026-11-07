import SwiftUI

/// The bundled logos of the third-party apps and services the app names
/// (`Assets.xcassets/Services/svc-*`, from selfh.st icons, CC BY 4.0; never
/// loaded from the network). `asset(for:)` reads free text (a name, kind or
/// host); nil means no logo, so the caller keeps its SF Symbol (webhook,
/// MDBList, rdt-client …).
enum ServiceLogo {
    /// Match order matters: the more specific word first ("jellyseerr" and
    /// "overseerr" both contain "seerr").
    private static let matches: [(needles: [String], asset: String)] = [
        (["decypharr"], "svc-decypharr"),
        (["jellyseerr"], "svc-jellyseerr"),
        (["overseerr"], "svc-overseerr"),
        (["seerr"], "svc-seerr"),
        (["sabnzbd"], "svc-sabnzbd"),
        (["nzbget"], "svc-nzbget"),
        (["qbittorrent", "qbit"], "svc-qbittorrent"),
        (["sonarr"], "svc-sonarr"),
        (["radarr"], "svc-radarr"),
        (["prowlarr"], "svc-prowlarr"),
        (["jellyfin"], "svc-jellyfin"),
        (["plex"], "svc-plex"),
        (["trakt"], "svc-trakt"),
        (["letterboxd"], "svc-letterboxd"),
        (["imdb"], "svc-imdb"),
        (["discord"], "svc-discord"),
        (["telegram"], "svc-telegram"),
        (["real-debrid", "realdebrid", "real debrid"], "svc-real-debrid"),
        (["rclone"], "svc-rclone"),
    ]

    /// The first logo any of `texts` names (case-insensitive contains), or nil.
    static func asset(for texts: String?...) -> String? {
        let haystack = texts.compactMap { $0?.lowercased() }
        guard !haystack.isEmpty else { return nil }
        return matches.first { entry in
            entry.needles.contains { needle in haystack.contains { $0.contains(needle) } }
        }?.asset
    }

    /// A download client's logo: the protocol's client (SABnzbd for Usenet,
    /// qBittorrent for torrent) unless the name or host names NZBGet. The
    /// decypharr shims ("SABnzbd (decypharr)") keep the protocol logo.
    static func downloadClient(name: String, host: String, isTorrent: Bool) -> String {
        if !isTorrent, "\(name) \(host)".lowercased().contains("nzbget") {
            return "svc-nzbget"
        }
        return isTorrent ? "svc-qbittorrent" : "svc-sabnzbd"
    }
}

/// A service logo drawn inline at `size` points (badges, labels). Decorative:
/// the text beside it names the service.
struct ServiceLogoMark: View {
    let asset: String
    var size: CGFloat = 16

    var body: some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
