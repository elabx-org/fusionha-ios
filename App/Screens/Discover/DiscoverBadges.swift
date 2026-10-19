import SwiftUI
import UIKit
import WebKit
import FusionhaKit

// MARK: PosterStatusBadge

enum PosterBadgeKind { case inLibrary, trending, caution }

struct PosterStatusBadge: View {
    let kind: PosterBadgeKind

    var body: some View {
        Group {
            switch kind {
            case .inLibrary:
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.done)
            case .trending:
                Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(Theme.onair)
            case .caution:
                Image(systemName: "exclamationmark.triangle").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.miss)
            }
        }
        .frame(width: 27, height: 27)
        .background(Theme.scrim.opacity(0.5), in: Circle())
        // The frosted plate stays dark on every palette (art is dark), so its
        // hairline and glyphs read on Daylight too.
        .background { Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark) }
        .overlay(Circle().strokeBorder(Theme.plateLine))
        .shadow(color: Theme.shelfShadow.opacity(0.8), radius: 7, y: 4)
        .accessibilityLabel(kind == .inLibrary ? "In library" : kind == .trending ? "Trending" : "Tracked, no file yet")
    }
}

// MARK: Kind glyphs

/// The torii gate the web uses for anime.
struct DiscoverToriiShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // Top beam (kasagi), slightly wider, then the lower tie beam (nuki).
        p.move(to: CGPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - w * 0.04, y: rect.minY + h * 0.2),
                       control: CGPoint(x: rect.midX, y: rect.minY + h * 0.3))
        p.move(to: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.42))
        p.addLine(to: CGPoint(x: rect.maxX - w * 0.16, y: rect.minY + h * 0.42))
        // Posts.
        p.move(to: CGPoint(x: rect.minX + w * 0.28, y: rect.minY + h * 0.24))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.25, y: rect.maxY - h * 0.06))
        p.move(to: CGPoint(x: rect.maxX - w * 0.28, y: rect.minY + h * 0.24))
        p.addLine(to: CGPoint(x: rect.maxX - w * 0.25, y: rect.maxY - h * 0.06))
        return p
    }
}

/// Film / TV / torii, the web's per-kind card glyph.
struct DiscoverKindGlyph: View {
    let kind: MediaKind
    let isAnime: Bool
    var size: CGFloat = 13
    var color: Color = Theme.mut

    var body: some View {
        if isAnime {
            DiscoverToriiShape()
                .stroke(color, style: StrokeStyle(lineWidth: max(1.2, size / 10), lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
                .accessibilityLabel("Anime")
        } else {
            Image(systemName: kind == .movie ? "film" : "tv")
                .font(.system(size: size * 0.85, weight: .regular))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .accessibilityLabel(kind == .movie ? "Movie" : "Series")
        }
    }
}

// MARK: Status wash + empty state

extension View {
    /// The ambient status wash: the status colour bleeds from the left over `base`.
    func statusWash(_ color: Color, base: Color = Theme.panel, radius: CGFloat = 14) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(stops: [.init(color: color.opacity(0.13), location: 0),
                                             .init(color: .clear, location: 0.42)],
                                     startPoint: .leading, endPoint: .trailing))
                .background(base, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.line))
    }
}

/// `ui/EmptyState`: dashed hairline box, 13.5pt muted copy.
struct DiscoverEmptyState: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13.5))
            .lineSpacing(13.5 * 0.6 - 4)
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}

/// A 13pt rail/list state line ("Loading…", "Could not load this rail.").
struct RailStateLine: View {
    let text: String
    var error = false

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(error ? Theme.danger : Theme.mut)
            .padding(.vertical, 20)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Uppercase section label used in dialogs ("EDITIONS", "ADD OPTIONS").
struct DialogSectionLabel: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(text.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.66)
                .foregroundStyle(Theme.mut)
            if let trailing {
                Text(trailing).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dim)
            }
        }
    }
}

// MARK: Request status

enum RequestStatusStyle {
    static func color(_ status: String) -> Color {
        switch status {
        case "approved": return Theme.grab
        case "rejected": return Theme.danger
        case "deferred": return Theme.stuck
        case "fulfilled": return Theme.done
        default: return Theme.dim
        }
    }
}

struct RequestStatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.22)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            // Status is a wash, never a border.
            .background(Theme.panel2, in: Capsule())
    }
}

enum DiscoverRelativeTime {
    /// The web's `formatLastRun`: "just now", "N min ago", "N hr ago", "N day(s) ago".
    static func string(_ iso: String?) -> String {
        guard let date = Format.timestamp(iso) else { return "" }
        let seconds = Date().timeIntervalSince(date)
        if seconds < 45 { return "just now" }
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(max(1, minutes)) min ago" }
        let hours = Int((seconds / 3600).rounded())
        if hours < 24 { return "\(hours) hr ago" }
        let days = Int((seconds / 86400).rounded())
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }
}
