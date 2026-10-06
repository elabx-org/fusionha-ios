import SwiftUI
import WidgetKit

/// Every widget's compact header: the fusionha glyph, the widget's title and
/// one status figure (`5`, `6/7`), then an optional control (the paged
/// widget's dots, Process queue).
struct WidgetTopBar<Trailing: View>: View {
    let title: String
    var figure: String?
    var tint: Color = .secondary
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            WidgetGlyph()
            Text(title)
                .font(WidgetStyle.title)
                .lineLimit(1)
                .widgetAccentable()
            Spacer(minLength: 4)
            if let figure {
                Text(figure)
                    .font(WidgetStyle.numeral(13))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .widgetAccentable()
            }
            trailing
        }
        .frame(height: WidgetStyle.headerHeight)
    }
}

extension WidgetTopBar where Trailing == EmptyView {
    init(title: String, figure: String? = nil, tint: Color = .secondary) {
        self.init(title: title, figure: figure, tint: tint) { EmptyView() }
    }
}

/// The fusionha mark, header-sized. Accented rendering tints it like the title.
struct WidgetGlyph: View {
    var size: CGFloat = 16

    var body: some View {
        Image("WidgetGlyph")
            .resizable()
            .interpolation(.high)
            .widgetAccentedRenderingMode(.accented)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
