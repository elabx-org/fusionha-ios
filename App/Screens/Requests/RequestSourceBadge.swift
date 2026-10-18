import SwiftUI
import FusionhaKit

/// The small mark of an automatic source (web `SourceMark`): Plex's list mark
/// for the Plex watchlist and lists, a film mark for Letterboxd; nothing for a
/// manual request.
struct RequestSourceGlyph: View {
    let kind: String?
    var size: CGFloat = 10

    var body: some View {
        if let kind, let style = Self.style(kind) {
            Image(systemName: style.symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(style.tint)
                .accessibilityHidden(true)
        }
    }

    static func style(_ kind: String) -> (symbol: String, tint: Color)? {
        if RequestSourceWords.plexKinds.contains(kind) { return ("list.bullet", Color(hex: 0xE5A00D)) }
        if RequestSourceWords.letterboxdKinds.contains(kind) { return ("film", Theme.done) }
        return nil
    }
}

/// The inbox row's source mark: a 22 pt circle holding the 12 pt glyph.
struct RequestSourceMark: View {
    let kind: String?

    var body: some View {
        if let kind, let style = RequestSourceGlyph.style(kind) {
            RequestSourceGlyph(kind: kind, size: 12)
                .frame(width: 22, height: 22)
                .background(style.tint.opacity(0.16), in: Circle())
        }
    }
}

/// Where a request came from (web `SourceBadge`): the mark and "From your
/// Plex watchlist" to its owner, "Plex list · Kids movies" to an approver.
struct RequestSourceBadge: View {
    let source: RequestSource?
    let mine: Bool

    var body: some View {
        HStack(spacing: 4) {
            RequestSourceGlyph(kind: source?.kind, size: 10)
            Text(RequestLifecycle.sourceText(source, mine: mine))
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.mut)
        .lineLimit(1)
    }
}
