import SwiftUI
import FusionhaKit

// The phone hero shared by the Preview page and the Add sheet's configure step
// (the web's `MobileHero`, shared since 0.4.130): the crisp poster masked into
// the page, status chip, title + year, tagline, a meta line and genre chips,
// The art stays clean: Close, Back and Add are the page's system toolbar items.

/// The ambient colour bleed behind the page: the art, blurred and dimmed.
struct PreviewAmbient: View {
    let art: String?

    var body: some View {
        if let art {
            // Rendered once into a cached bitmap (`AmbientArt`), not a live blur(72).
            AmbientArt(url: TMDBImage.resized(art, to: "w342"), kind: .previewAmbient, aspect: 2 / 3)
                .overlay {
                    LinearGradient(stops: [.init(color: Theme.bg.opacity(0.78), location: 0),
                                           .init(color: Theme.bg.opacity(0.62), location: 0.3),
                                           .init(color: Theme.bg.opacity(0.5), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

struct PreviewHero: View {
    enum Meta: Hashable {
        case text(String)
        case rating(Double)
        case cert(String)
    }

    let art: String?
    let status: String?
    let title: String
    let year: Int?
    let tagline: String?
    let meta: [Meta]
    let genres: [String]
    /// v2's one ink: the status chip in the label colour, never a hue.
    var oneInk = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let art {
                    DiscoverArt(url: TMDBImage.resized(art, to: "original"))
                        .mask {
                            LinearGradient(stops: [.init(color: .black, location: 0),
                                                   .init(color: .black, location: 0.4),
                                                   .init(color: .clear, location: 0.74)],
                                           startPoint: .top, endPoint: .bottom)
                        }
                } else {
                    RadialGradient(colors: [Theme.panel2, Theme.bg], center: .top, startRadius: 0, endRadius: 420)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(stops: [.init(color: Theme.bg.opacity(0.14), location: 0),
                                   .init(color: .clear, location: 0.26),
                                   .init(color: Theme.bg.opacity(0.42), location: 0.62),
                                   .init(color: Theme.bg.opacity(0.3), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            overlay
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        // The 430 floor gives way to 75% of a short container (the Duo's outer
        // display sideways, 466pt tall), like the detail hero (D3).
        .containerRelativeFrame(.vertical) { height, _ in min(max(height * 0.62, min(430, height * 0.75)), 600) }
        .clipped()
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let status, !status.isEmpty {
                StatusToneChip(status: status, oneInk: oneInk).padding(.bottom, 10)
            }
            (Text(title).font(.system(size: 33, weight: .black)).tracking(-0.66)
             + Text(verbatim: year.map { " \($0)" } ?? "").font(.system(size: 33, weight: .semibold)).foregroundColor(Theme.txt.opacity(0.78)))
                .foregroundStyle(Theme.txt)
                .lineSpacing(-2)
                .shadow(color: .black.opacity(0.6), radius: 10, y: 3)
            if let tagline, !tagline.isEmpty {
                Text(tagline).font(.system(size: 13)).italic().foregroundStyle(Theme.txt.opacity(0.86))
                    .readableWidth()
                    .padding(.top, 8)
            }
            metaLine.padding(.top, 12)
            if !genres.isEmpty {
                PreviewFlow(spacing: 7) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.txt.opacity(0.88))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.panel.opacity(0.55), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private var metaLine: some View {
        HStack(spacing: 7) {
            ForEach(meta.indices, id: \.self) { index in
                if index > 0 { Text("·").opacity(0.5) }
                metaItem(meta[index])
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.txt.opacity(0.8))
        .lineLimit(1)
    }

    @ViewBuilder
    private func metaItem(_ item: Meta) -> some View {
        switch item {
        case .text(let text):
            Text(text)
        case .rating(let vote):
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(DetailTokens.star)
                Text(String(format: "%.1f", vote))
            }
        case .cert(let cert):
            Text(cert)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))
        }
    }
}

/// The hero status chip: clock icon + mono status, toned by meaning.
struct StatusToneChip: View {
    let status: String
    /// v2: the label ink (released, airing) or muted, never green or a status hue.
    var oneInk = false

    private var tone: (bg: Color, fg: Color, border: Color) {
        let s = status.lowercased()
        if oneInk {
            let known = ["released", "available", "ended", "continuing", "returning", "airing", "on air"]
                .contains(where: { s.contains($0) })
            return (Theme.txt.opacity(0.08), known ? Theme.txt : Theme.mut, Theme.txt.opacity(0.2))
        }
        if ["released", "available", "ended"].contains(where: { s.contains($0) }) {
            return (Theme.done.opacity(0.16), Theme.done, Theme.done.opacity(0.3))
        }
        if ["continuing", "returning", "airing", "on air", "production", "planned", "upcoming"].contains(where: { s.contains($0) }) {
            return (Theme.onair.opacity(0.16), Theme.onair, Theme.onair.opacity(0.3))
        }
        return (Theme.panel2, Theme.mut, Theme.line)
    }

    var body: some View {
        let t = tone
        HStack(spacing: 5) {
            Image(systemName: "clock").font(.system(size: 11, weight: .semibold))
            Text(status).font(.system(size: 11, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(t.fg)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(t.bg, in: Capsule())
        .overlay(Capsule().strokeBorder(t.border))
    }
}

/// Zooms a pushed page out of its `matchedTransitionSource`, unless motion is off
/// (Reduce Motion or the admin's switch), where the push stays the system default.
struct ZoomTransition: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    @Environment(\.motionEnabled) private var motion

    func body(content: Content) -> some View {
        if motion {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}
