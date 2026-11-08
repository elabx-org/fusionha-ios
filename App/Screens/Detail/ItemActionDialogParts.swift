import SwiftUI

// Shared pieces of the item action sheets (rename, edition aliases, numbering):
// the web dialogs' icon header, muted note and dashed empty box.

/// The DialogHeader: a bare icon (`tint` is kept for callers, unused), the title and a one-line subtitle.
struct DialogHeading: View {
    let symbol: String
    let title: String
    let subtitle: String
    var tint: Color = Theme.edition

    var body: some View {
        #if V2
        // v2's form sheet (Look Pass family 1): large title, muted line, no icon.
        V2SheetHeading(title: title, subtitle: subtitle)
        #else
        v1Body
        #endif
    }

    private var v1Body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.txt)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 4)
    }
}

/// A muted status line ("Building preview…").
struct DialogNote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The dashed "nothing to do" box.
struct DialogEmpty: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(.center)
            .padding(18)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }
}

/// A tinted banner (queue blocked, admin required, stale preview).
struct DialogBanner: View {
    let text: String
    var tint: Color = Theme.miss

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(tint.mix(0.55, Theme.txt))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(tint.opacity(0.35)))
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// The item action sheets' fill: `color` in v1; in v2 nothing, so the
    /// sheet is the system's glass (Look Pass family 1, the form sheet).
    @ViewBuilder
    func dialogGround(_ color: Color) -> some View {
        #if V2
        self
        #else
        self.background(color)
        #endif
    }

    /// The item action sheets' presentation background: `color` in v1, the
    /// system's glass sheet in v2.
    @ViewBuilder
    func dialogSheetBackground(_ color: Color) -> some View {
        #if V2
        self
        #else
        self.sheetBackground(color)
        #endif
    }
}
