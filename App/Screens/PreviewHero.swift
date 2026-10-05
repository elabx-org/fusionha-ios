import SwiftUI
import FusionhaKit

// The phone hero shared by the Preview page and the Add sheet's configure step
// (the web's `MobileHero`, shared since 0.4.130): the crisp poster masked into
// the page, status chip, title + year, tagline, a meta line and genre chips,
// with the round close (and optional back) buttons over the art.

/// The ambient colour bleed behind the page: the art, blurred and dimmed.
struct PreviewAmbient: View {
    let art: String?

    var body: some View {
        if let art {
            GeometryReader { geo in
                DiscoverArt(url: TMDBImage.resized(art, to: "w342"))
                    .frame(width: geo.size.width * 1.28, height: geo.size.height * 1.28)
                    .offset(x: -geo.size.width * 0.14, y: -geo.size.height * 0.14)
                    .blur(radius: 72)
                    .saturation(1.4)
                    .brightness(-0.12)
                    .overlay {
                        LinearGradient(stops: [.init(color: Theme.bg.opacity(0.78), location: 0),
                                               .init(color: Theme.bg.opacity(0.62), location: 0.3),
                                               .init(color: Theme.bg.opacity(0.5), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
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
    var closeLabel = "Close"
    let onClose: () -> Void
    var onBack: (() -> Void)?
    var backLabel = "Back"

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let art {
                    DiscoverArt(url: TMDBImage.resized(art, to: "w780"))
                        .mask {
                            LinearGradient(stops: [.init(color: .black, location: 0),
                                                   .init(color: .black, location: 0.4),
                                                   .init(color: .clear, location: 0.74)],
                                           startPoint: .top, endPoint: .bottom)
                        }
                } else {
                    RadialGradient(colors: [Color(hex: 0x1B1F2E), Theme.bg], center: .top, startRadius: 0, endRadius: 420)
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
        .containerRelativeFrame(.vertical) { height, _ in min(max(height * 0.62, 430), 600) }
        .clipped()
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                roundButton("xmark", label: closeLabel, action: onClose)
                if let onBack { roundButton("chevron.left", label: backLabel, action: onBack) }
            }
            .padding(.leading, 12)
            .padding(.top, 8)
        }
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color(hex: 0x0C0D11).opacity(0.5), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.line))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let status, !status.isEmpty {
                StatusToneChip(status: status).padding(.bottom, 10)
            }
            (Text(title).font(.system(size: 33, weight: .black)).tracking(-0.66)
             + Text(verbatim: year.map { " \($0)" } ?? "").font(.system(size: 33, weight: .semibold)).foregroundColor(Theme.txt.opacity(0.78)))
                .foregroundStyle(Theme.txt)
                .lineSpacing(-2)
                .shadow(color: .black.opacity(0.6), radius: 10, y: 3)
            if let tagline, !tagline.isEmpty {
                Text(tagline).font(.system(size: 13)).italic().foregroundStyle(Theme.txt.opacity(0.86))
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
                Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(Color(hex: 0xF5C518))
                Text(String(format: "%.1f", vote))
            }
        case .cert(let cert):
            Text(cert)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))
        }
    }
}

/// The hero status chip: clock icon + mono uppercase status, toned by meaning.
struct StatusToneChip: View {
    let status: String

    private var tone: (bg: Color, fg: Color, border: Color) {
        let s = status.lowercased()
        if ["released", "available", "ended"].contains(where: { s.contains($0) }) {
            return (Color(hex: 0x143C32), Color(hex: 0x7CDCBC), Color(hex: 0x7CDCBC).opacity(0.3))
        }
        if ["continuing", "returning", "airing", "on air", "production", "planned", "upcoming"].contains(where: { s.contains($0) }) {
            return (Color(hex: 0x443716), Color(hex: 0xF4D076), Color(hex: 0xF4D076).opacity(0.3))
        }
        return (Color(hex: 0x2A2D34), Theme.mut, Theme.line)
    }

    var body: some View {
        let t = tone
        HStack(spacing: 5) {
            Image(systemName: "clock").font(.system(size: 11, weight: .semibold))
            Text(status.uppercased()).font(.system(size: 10, weight: .heavy, design: .monospaced)).tracking(0.4)
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
