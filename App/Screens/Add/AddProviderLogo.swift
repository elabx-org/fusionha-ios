import SwiftUI

/// The Details card's provider mark (the web's `DetailsCard` `ProviderLogo`):
/// the real wordmark for TMDB / TVDB / TVmaze, the Hybrid ring mark for
/// Hybrid, and a dimmed ring mark for Automatic.
struct AddProviderLogo: View {
    let provider: String
    var size: CGFloat = 14

    var body: some View {
        switch provider {
        case "tmdb": TmdbLogo(size: size)
        case "tvdb": TvdbLogo(size: size)
        case "tvmaze": TvmazeLogo(size: size)
        case "auto":
            HybridMark(size: size + 3)
                .opacity(0.5)
                .saturation(0.5)
        default:
            HybridMark(size: size + 3)
        }
    }
}

/// A provider mark and its name, e.g. "[logo] TVDB" (the web's `ProviderValue`).
struct AddProviderValue: View {
    let provider: String
    var size: CGFloat = 14

    static let names: [String: String] = [
        "auto": "Automatic", "tmdb": "TMDB", "tvdb": "TVDB", "tvmaze": "TVmaze", "hybrid": "Hybrid",
    ]

    var body: some View {
        HStack(spacing: 6) {
            AddProviderLogo(provider: provider, size: size)
            Text(Self.names[provider] ?? provider)
        }
    }
}
