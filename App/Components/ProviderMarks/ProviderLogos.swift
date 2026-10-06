import SwiftUI

// The official provider marks (the web's `metadata-logos.tsx`). Every mark is
// sized by HEIGHT only; the width follows the artwork's own aspect ratio.
// Decorative by default: pass `label` where no adjacent text names the source.

/// The Movie Database mark, in its fixed-dark contrast chip (TMDB's palest
/// gradient stop reads poorly on a light surface).
struct TmdbLogo: View {
    var size: CGFloat = 40
    var label: String?

    var body: some View {
        Image("tmdb-logo")
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(hex: 0x0D253F), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.white.opacity(0.07)))
            .providerMarkAccessibility(label)
    }
}

/// TheTVDB mark. The asset carries TheTVDB's two official variants (white
/// text for dark surfaces, dark text for light ones), picked by appearance.
struct TvdbLogo: View {
    var size: CGFloat = 40
    var label: String?

    var body: some View {
        Image("tvdb-logo")
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .providerMarkAccessibility(label)
    }
}

/// TVmaze mark, in its fixed-dark contrast chip.
struct TvmazeLogo: View {
    var size: CGFloat = 40
    var label: String?

    var body: some View {
        Image("tvmaze-logo")
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(hex: 0x150E0E), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.white.opacity(0.07)))
            .providerMarkAccessibility(label)
    }
}

/// A provider by key, the way the web shows it everywhere: TMDB / TVDB /
/// TVmaze are logo-only (the wordmark spells the name), Hybrid is the ring
/// mark (3pt taller than the wordmarks) beside a visible "Hybrid" label.
/// The label inherits the caller's font and colour. Unknown keys fall back
/// to TMDB (TMDB is mandatory).
struct ProviderMark: View {
    let provider: String
    /// The wordmark height; the Hybrid ring mark is `size + 3`.
    var size: CGFloat = 12
    /// Hide the "Hybrid" text (for a context that names it already).
    var hybridText = true

    var body: some View {
        switch provider.lowercased() {
        case "tvdb":
            TvdbLogo(size: size, label: "TVDB")
        case "tvmaze":
            TvmazeLogo(size: size, label: "TVmaze")
        case "hybrid":
            HStack(spacing: 5) {
                HybridMark(size: size + 3, label: hybridText ? nil : "Hybrid")
                if hybridText { Text("Hybrid").fontWeight(.semibold) }
            }
        default:
            TmdbLogo(size: size, label: "TMDB")
        }
    }
}

private extension View {
    @ViewBuilder
    func providerMarkAccessibility(_ label: String?) -> some View {
        if let label {
            accessibilityElement().accessibilityLabel(label).accessibilityAddTraits(.isImage)
        } else {
            accessibilityHidden(true)
        }
    }
}
